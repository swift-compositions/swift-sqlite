// swift-sqlite#25, the three more cases, on the mechanism that holds (Holds.swift).
//
//   swiftc -swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault Cases.swift -o cases
//   ./cases busy 20000          case 1: a listener that is between two `next` calls when a post happens
//   ./cases stuck               case 1: a listener that never reads again
//   ./cases many 20000          case 3: several listeners for one post, one after another against together
//   ./cases own 20000           a loop body that awaits a post on the same hub
//   ./cases cross               two listeners whose bodies post at the same time
//   ./cases cancel 2000         a listener that is cancelled while posts wait for it
//   ./cases body 20000          the decided rule: a post from a loop body waits for nobody
//   ./cases child               a loop body that posts from a child task
//
// Case 2, a listener on no actor, is a compile-time question: see Isolation/.
//
// A hub keeps the latest posted number for each listener, not a queue. `follow()` registers a listener with the
// actor it is called on. `post` publishes the next number to every listener, in registration order and under one
// lock, as a writer would after a commit. Then it waits for each listener.

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Synchronization

// MARK: - What a post does for a listener that is busy

/// A listener is busy when it is between two `next` calls and its body has suspended: it is not waiting for a
/// number, and it does not hold its actor.
enum Busy: String, Sendable, CaseIterable {
    /// The post does not wait for a busy listener. That listener gets the latest number, at once, on its next `next`.
    case latest = "the post does not wait for a busy listener"
    /// The post returns only after the busy listener has come back and handled the number, or a later one.
    case waits = "the post waits for a busy listener"
}

/// Which listeners a waiting post does not wait for.
enum Exempt: String, Sendable, CaseIterable {
    /// Only the listener whose loop body made the post.
    case own = "the post does not wait for the posting task's own listener"
    /// Every listener whose loop body is inside a post now.
    case posting = "the post does not wait for a listener that is inside a post"
    /// The decided rule. A post from a listener's loop body delivers to every listener and returns. It waits for
    /// nobody. A post from anywhere else waits for every listener.
    case body = "a post from a loop body waits for nobody"
}

/// The identity of the current task, to know a listener's own post. An address: it is valid as an identity only
/// while that task lives, and the listener's task lives while its loop runs.
func currentTask() -> UInt {
    withUnsafeCurrentTask { task in task.map { unsafeBitCast($0, to: UInt.self) } ?? 0 }
}

enum Fanout: String, Sendable, CaseIterable {
    /// One listener after the other, in registration order.
    case sequential = "one after another"
    /// All handshakes at the same time, each in a child task.
    case together = "together"
}

// MARK: - One listener

final class Subscription: Sendable {
    /// What `publish` found, for the wait that follows it.
    enum Published: Sendable {
        /// The listener is gone, or the hub is finished.
        case nobody
        /// The listener waited for a number. This continuation is its `next`.
        case waiter(CheckedContinuation<Int?, Never>)
        /// The listener did not wait. The number is kept as the latest.
        case kept
    }

    private struct State {
        /// The latest number that the listener has not taken yet.
        var latest: Int?
        /// The highest number that the listener took.
        var taken = 0
        var waiter: CheckedContinuation<Int?, Never>?
        /// The waiter was taken out to be resumed, and its `next` is not yet back on the listener's actor.
        var transit = false
        /// Posters that wait, each until the listener has taken a number that is not below `need`.
        var acknowledgements: [(need: Int, continuation: CheckedContinuation<Void, Never>)] = []
        var gone = false
        var finished = false
        /// The task that iterates: the one that called `next` last.
        var task: UInt = 0
        /// How many posts the listener's body is inside now.
        var posting = 0
    }

    /// The listener's actor, known from `follow()` on.
    let isolation: any Actor
    private let state = Mutex(State())

    init(isolation: any Actor) { self.isolation = isolation }

    // The listener's side.

    func next(isolation actor: isolated (any Actor)?) async -> Int? {
        // The compile-time rule of Isolation/ leaves this as the last line of defence.
        guard actor === isolation else {
            report("a followed read was iterated off the actor that asked for it; the sequence ends")
            leave()
            return nil
        }

        // A cancelled listener is a listener that is gone: nothing may wait for it.
        if Task.isCancelled {
            leave()
            return nil
        }
        let task = currentTask()

        let value: Int? = await withTaskCancellationHandler {
          await withCheckedContinuation { continuation in
            var released: [CheckedContinuation<Void, Never>] = []
            let ready: Int?? = state.withLock { state in
                state.task = task
                if let latest = state.latest {
                    // Taken with no suspension: the body for it runs in the job that runs now.
                    state.latest = nil
                    state.taken = latest
                    released = Self.release(&state)
                    return .some(latest)
                }
                if state.finished || state.gone { return .some(nil) }
                state.waiter = continuation
                return nil
            }
            for acknowledgement in released { acknowledgement.resume() }
            if let ready { continuation.resume(returning: ready) }
          }
        } onCancel: {
            // Cancelled while it waits for a number: the waiter gets `nil`, and the posts that wait go on.
            leave()
        }

        // Back on the listener's actor, which the listener keeps until its body suspends or asks for the next number.
        let released = state.withLock { state in
            state.transit = false
            if let value { state.taken = max(state.taken, value) }
            return Self.release(&state)
        }
        for acknowledgement in released { acknowledgement.resume() }
        return value
    }

    private static func release(_ state: inout State) -> [CheckedContinuation<Void, Never>] {
        let done = state.acknowledgements.filter { $0.need <= state.taken }.map(\.continuation)
        state.acknowledgements.removeAll { $0.need <= state.taken }
        return done
    }

    /// The listener's iterator is gone, or the hub is finished. Nobody may wait for this listener any more.
    func leave(finished: Bool = false) {
        let (waiter, waiting) = state.withLock { state in
            if finished { state.finished = true } else { state.gone = true }
            defer {
                state.waiter = nil
                state.acknowledgements = []
            }
            return (state.waiter, state.acknowledgements.map(\.continuation))
        }
        waiter?.resume(returning: nil)
        for acknowledgement in waiting { acknowledgement.resume() }
    }

    // The poster's side.

    /// Whether `task` is the task of this listener's loop.
    func isListener(_ task: UInt) -> Bool {
        task != 0 && state.withLock { $0.task == task && !$0.gone && !$0.finished }
    }

    /// The listener's body enters a post. With `Exempt.posting`, the posts that wait for this listener go on: it
    /// cannot read while it is inside a post.
    func enterPost(_ exempt: Exempt) {
        let released: [CheckedContinuation<Void, Never>] = state.withLock { state in
            state.posting += 1
            guard exempt == .posting else { return [] }
            defer { state.acknowledgements.removeAll { $0.need > 0 } }
            return state.acknowledgements.filter { $0.need > 0 }.map(\.continuation)
        }
        for acknowledgement in released { acknowledgement.resume() }
    }

    func leavePost() {
        state.withLock { $0.posting -= 1 }
    }

    /// Synchronous, and called in the order of the numbers.
    func publish(_ number: Int) -> Published {
        state.withLock { state in
            if state.gone || state.finished { return .nobody }
            if let waiter = state.waiter {
                state.waiter = nil
                state.transit = true
                return .waiter(waiter)
            }
            state.latest = number
            return .kept
        }
    }

    /// Runs on the listener's actor, and returns on it. So it returns when no job of the listener runs there.
    func settle(
        _ published: Published, _ number: Int, _ busy: Busy, own: Bool = false, exempt: Exempt = .own,
        on actor: isolated any Actor
    ) async {
        await withCheckedContinuation { (acknowledgement: CheckedContinuation<Void, Never>) in
            var waiter: CheckedContinuation<Int?, Never>?
            var answer: Int? = number
            let wait: Bool = state.withLock { state in
                if state.gone || state.finished {
                    // The listener left, or was cancelled, after `publish` took its waiter out. That waiter must
                    // still be resumed, by the one that holds it: here.
                    if case .waiter(let continuation) = published {
                        waiter = continuation
                        answer = nil
                    }
                    return false
                }
                switch published {
                case .nobody:
                    return false
                case .waiter(let continuation):
                    // The handshake: the acknowledgement is stored before the listener is resumed.
                    waiter = continuation
                    state.acknowledgements.append((number, acknowledgement))
                    return true
                case .kept:
                    // The listener took this number, or a later one, in a job that is over: this runs on its actor.
                    if state.taken >= number { return false }
                    if state.transit {
                        // Another poster resumed the listener, and it is on its way back to its actor. In the job
                        // that starts there it takes the latest number too, unless its body suspends first.
                        state.acknowledgements.append((busy == .waits ? number : 0, acknowledgement))
                        return true
                    }
                    // The listener is busy: its body has suspended, or it has not asked for a first number.
                    guard busy == .waits else { return false }
                    // The post came from this listener's own body: it cannot read before the post returns.
                    if own { return false }
                    if exempt == .posting && state.posting > 0 { return false }
                    state.acknowledgements.append((number, acknowledgement))
                    return true
                }
            }
            waiter?.resume(returning: answer)
            if !wait { acknowledgement.resume() }
        }
    }
}

func report(_ issue: String) {
    let line = "ISSUE: \(issue)\n"
    _ = line.withCString { write(2, $0, strlen($0)) }
}

// MARK: - The hub and its sequence

final class Hub: Sendable {
    private struct State {
        var posted = 0
        var subscriptions: [Subscription] = []
    }

    private let state = Mutex(State())

    var listeners: Int { state.withLock { $0.subscriptions.count } }
    var posted: Int { state.withLock { $0.posted } }

    /// Registers a listener on the actor of the caller. A caller on no actor does not compile: Isolation/.
    func follow(isolation: isolated any Actor = #isolation) -> Values {
        let subscription = Subscription(isolation: isolation)
        state.withLock { $0.subscriptions.append(subscription) }
        return Values(token: Token(subscription))
    }

    /// Posts the next number to every listener, and waits for them. Returns the number.
    nonisolated(nonsending) func post(_ busy: Busy, _ fanout: Fanout = .sequential, exempt: Exempt = .own) async -> Int {
        let task = currentTask()
        let (number, published) = state.withLock { state in
            state.posted += 1
            return (state.posted, state.subscriptions.map { ($0, $0.publish(state.posted)) })
        }
        // The listeners whose loop body is this very task. They get the number as their latest, on their next read.
        let own = published.map(\.0).filter { $0.isListener(task) }
        if exempt == .body && !own.isEmpty {
            // Delivered to every listener by `publish`. A listener that waited in `next` is resumed here, with no
            // handshake: nobody waits for it. No suspension in this branch.
            for (_, published) in published {
                if case .waiter(let waiter) = published { waiter.resume(returning: number) }
            }
            return number
        }
        for subscription in own { subscription.enterPost(exempt) }
        defer { for subscription in own { subscription.leavePost() } }

        switch fanout {
        case .sequential:
            for (subscription, published) in published {
                let isOwn = own.contains { $0 === subscription }
                await subscription.settle(published, number, busy, own: isOwn, exempt: exempt, on: subscription.isolation)
            }
        case .together:
            await withTaskGroup(of: Void.self) { group in
                for (subscription, published) in published {
                    let isOwn = own.contains { $0 === subscription }
                    group.addTask {
                        await subscription.settle(published, number, busy, own: isOwn, exempt: exempt, on: subscription.isolation)
                    }
                }
            }
        }
        return number
    }

    func finish() {
        for subscription in state.withLock({ $0.subscriptions }) { subscription.leave(finished: true) }
    }
}

/// Lives as long as the listener's sequence and its iterators.
final class Token {
    let subscription: Subscription
    init(_ subscription: Subscription) { self.subscription = subscription }
    deinit { subscription.leave() }
}

/// Not Sendable, because `Token` is not: the sequence stays with the actor that asked for it.
struct Values: AsyncSequence {
    typealias Element = Int
    typealias Failure = Never

    let token: Token

    func makeAsyncIterator() -> Iterator { Iterator(token: token) }

    struct Iterator: AsyncIteratorProtocol {
        let token: Token

        mutating func next() async -> Int? {
            await token.subscription.next(isolation: #isolation)
        }

        mutating func next(isolation actor: isolated (any Actor)?) async -> Int? {
            await token.subscription.next(isolation: actor)
        }
    }
}

// MARK: - A custom serial executor

final class ThreadExecutor: SerialExecutor, @unchecked Sendable {
    private let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    private let condition = UnsafeMutablePointer<pthread_cond_t>.allocate(capacity: 1)
    private var jobs: [UnownedJob] = []
    private var head = 0

    init() {
        pthread_mutex_init(mutex, nil)
        pthread_cond_init(condition, nil)
        #if canImport(Darwin)
        var handle: pthread_t?
        pthread_create(&handle, nil, { raw in
            Unmanaged<ThreadExecutor>.fromOpaque(raw).takeRetainedValue().run()
            return nil
        }, Unmanaged.passRetained(self).toOpaque())
        #else
        var handle = pthread_t()
        pthread_create(&handle, nil, { raw in
            Unmanaged<ThreadExecutor>.fromOpaque(raw!).takeRetainedValue().run()
            return nil
        }, Unmanaged.passRetained(self).toOpaque())
        #endif
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        pthread_mutex_lock(mutex)
        jobs.append(job)
        pthread_cond_signal(condition)
        pthread_mutex_unlock(mutex)
    }

    private func run() {
        pthread_mutex_lock(mutex)
        while true {
            while head == jobs.count { pthread_cond_wait(condition, mutex) }
            let job = jobs[head]
            head += 1
            if head > 1024 {
                jobs.removeFirst(head)
                head = 0
            }
            pthread_mutex_unlock(mutex)
            job.runSynchronously(on: asUnownedSerialExecutor())
            pthread_mutex_lock(mutex)
        }
    }
}

// MARK: - Listeners

/// What a listener's body does.
enum Body: String, Sendable, CaseIterable {
    /// `record(number)`, and no suspension.
    case synchronous = "synchronous body"
    /// `record(number)`, and then a suspension for two numbers of three: the listener is busy.
    case suspends = "body that suspends"
    /// `record(number)`, and for one number of five the body awaits a post on the same hub.
    case posts = "body that posts"
    /// The same, and the body also suspends for two numbers of three.
    case postsAndSuspends = "body that posts and suspends"
}

/// What a body that posts needs.
final class Reaction: Sendable {
    let hub: Hub
    let exempt: Exempt
    /// The body posts only while the hub has posted fewer numbers than this.
    let limit: Int
    private let probes = Mutex<[Probe]>([])
    private let early = Atomic<Int>(0)
    private let made = Atomic<Int>(0)

    init(hub: Hub, exempt: Exempt, limit: Int) {
        self.hub = hub
        self.exempt = exempt
        self.limit = limit
    }

    func add(_ probe: Probe) { probes.withLock { $0.append(probe) } }

    /// Posts from a loop body. When the post returns, every other listener must have handled its number.
    nonisolated(nonsending) func post(from own: Probe) async {
        guard hub.posted < limit else { return }
        let number = await hub.post(.waits, .together, exempt: exempt)
        made.add(1, ordering: .sequentiallyConsistent)
        let others = probes.withLock { $0.filter { $0 !== own } }
        if others.contains(where: { $0.last < number }) { early.add(1, ordering: .sequentiallyConsistent) }
    }

    var earlyPosts: Int { early.load(ordering: .sequentiallyConsistent) }
    var posts: Int { made.load(ordering: .sequentiallyConsistent) }
}

/// What one listener saw.
final class Probe: Sendable {
    private let seen = Atomic<Int>(0)
    private let disorder = Atomic<Int>(0)
    private let handled = Atomic<Int>(0)
    let reaction: Reaction?

    init(reaction: Reaction? = nil) {
        self.reaction = reaction
        reaction?.add(self)
    }

    var last: Int { seen.load(ordering: .sequentiallyConsistent) }
    /// Numbers that came after a higher number.
    var outOfOrder: Int { disorder.load(ordering: .sequentiallyConsistent) }
    var count: Int { handled.load(ordering: .sequentiallyConsistent) }

    /// The body of the loop. Its synchronous part is the first two lines.
    nonisolated(nonsending) func handle(_ number: Int, _ body: Body) async {
        if number <= last { disorder.add(1, ordering: .sequentiallyConsistent) }
        seen.store(number, ordering: .sequentiallyConsistent)
        handled.add(1, ordering: .sequentiallyConsistent)
        if (body == .suspends || body == .postsAndSuspends) && number % 3 != 0 { await Task.yield() }
        if (body == .posts || body == .postsAndSuspends) && number % 5 == 0 { await reaction?.post(from: self) }
    }
}

@MainActor func listenOnMain(_ hub: Hub, _ probe: Probe, _ body: Body) async {
    for await number in hub.follow() { await probe.handle(number, body) }
}

@MainActor func postOnMain(_ hub: Hub, _ busy: Busy, _ fanout: Fanout) async -> Int {
    await hub.post(busy, fanout)
}

actor DefaultActor {
    func listen(_ hub: Hub, _ probe: Probe, _ body: Body) async {
        for await number in hub.follow() { await probe.handle(number, body) }
    }
    func post(_ hub: Hub, _ busy: Busy, _ fanout: Fanout) async -> Int { await hub.post(busy, fanout) }
}

actor ThreadActor {
    nonisolated let executor = ThreadExecutor()
    nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

    func listen(_ hub: Hub, _ probe: Probe, _ body: Body) async {
        for await number in hub.follow() { await probe.handle(number, body) }
    }
    func post(_ hub: Hub, _ busy: Busy, _ fanout: Fanout) async -> Int { await hub.post(busy, fanout) }
}

enum Isolation: String, CaseIterable, Sendable {
    case main = "main actor"
    case `default` = "default actor"
    case thread = "custom executor"
}

enum Poster: String, CaseIterable, Sendable {
    case tasks = "no isolation"
    case actor = "another actor"
    case same = "the listener's isolation"
}

/// A listener of each kind, as a task. `first` is the isolation that posters use for `Poster.same`.
struct Listeners: Sendable {
    let defaultActor = DefaultActor()
    let threadActor = ThreadActor()
    let other = ThreadActor()

    func start(_ isolation: Isolation, _ hub: Hub, _ probe: Probe, _ body: Body, priority: TaskPriority) -> Task<Void, Never> {
        let defaultActor = isolation == .default ? DefaultActor() : self.defaultActor
        let threadActor = isolation == .thread ? ThreadActor() : self.threadActor
        return Task.detached(priority: priority) {
            switch isolation {
            case .main: await listenOnMain(hub, probe, body)
            case .default: await defaultActor.listen(hub, probe, body)
            case .thread: await threadActor.listen(hub, probe, body)
            }
        }
    }

    nonisolated(nonsending) func post(_ hub: Hub, _ busy: Busy, _ fanout: Fanout, from poster: Poster, _ isolation: Isolation) async -> Int {
        switch (poster, isolation) {
        case (.tasks, _): await hub.post(busy, fanout)
        case (.actor, _): await other.post(hub, busy, fanout)
        case (.same, .main): await postOnMain(hub, busy, fanout)
        case (.same, .default): await defaultActor.post(hub, busy, fanout)
        case (.same, .thread): await threadActor.post(hub, busy, fanout)
        }
    }
}

let priorities: [(TaskPriority, TaskPriority)] = [
    (.medium, .medium), (.low, .high), (.high, .low), (.background, .high), (.high, .background),
]

func name(_ priority: TaskPriority) -> String {
    switch priority {
    case .high: "high"
    case .medium: "medium"
    case .low: "low"
    case .background: "background"
    default: "\(priority.rawValue)"
    }
}

#if DEBUG
let build = "debug"
#else
let build = "-O"
#endif

func seconds() -> Double {
    var time = timespec()
    clock_gettime(CLOCK_MONOTONIC, &time)
    return Double(time.tv_sec) + Double(time.tv_nsec) / 1e9
}

// MARK: - Case 1: a busy listener

struct Outcome: Sendable {
    /// Posts that returned while the listener had not handled their number or a later one.
    var early = 0
    /// Numbers that a listener got after a higher number.
    var outOfOrder = 0
    /// Whether the listener handled the last number in the end.
    var sawLast = true
    var handled = 0
}

/// One listener, four posters. In the `same` position, the posters post from the listener's own actor.
func busy(_ mode: Busy, _ body: Body, _ isolation: Isolation, _ poster: Poster, _ listener: TaskPriority, _ posters: TaskPriority, posts: Int) async -> Outcome {
    let hub = Hub()
    let probe = Probe()
    let listeners = Listeners()
    let task: Task<Void, Never>
    switch isolation {
    case .main: task = Task.detached(priority: listener) { await listenOnMain(hub, probe, body) }
    case .default: task = Task.detached(priority: listener) { await listeners.defaultActor.listen(hub, probe, body) }
    case .thread: task = Task.detached(priority: listener) { await listeners.threadActor.listen(hub, probe, body) }
    }
    while hub.listeners < 1 { await Task.yield() }

    let early = await withTaskGroup(of: Int.self) { group in
        for _ in 0..<4 {
            group.addTask(priority: posters) {
                var early = 0
                for _ in 0..<(posts / 4) {
                    let number = await listeners.post(hub, mode, .sequential, from: poster, isolation)
                    if probe.last < number { early += 1 }
                }
                return early
            }
        }
        var total = 0
        for await early in group { total += early }
        return total
    }

    // With `latest`, the listener gets the last number on its next read. Give it time for that read.
    let last = hub.posted
    let deadline = seconds() + 5
    while probe.last < last && seconds() < deadline { await Task.yield() }
    let sawLast = probe.last == last
    hub.finish()
    await task.value
    return Outcome(early: early, outOfOrder: probe.outOfOrder, sawLast: sawLast, handled: probe.count)
}

func busyMatrix(posts: Int) async {
    print("build: \(build); posts per configuration: \(posts); 45 configurations per line:")
    print("3 isolations x 3 poster positions x 5 priority pairs")
    for mode in Busy.allCases {
        for body in Body.allCases {
            var total = Outcome()
            var earlyConfigurations = 0
            var notLast = 0
            var configurations = 0
            for isolation in Isolation.allCases {
                for poster in Poster.allCases {
                    for (listener, posters) in priorities {
                        let outcome = await busy(mode, body, isolation, poster, listener, posters, posts: posts)
                        configurations += 1
                        total.early += outcome.early
                        total.outOfOrder += outcome.outOfOrder
                        total.handled += outcome.handled
                        if outcome.early > 0 { earlyConfigurations += 1 }
                        if !outcome.sawLast { notLast += 1 }
                    }
                }
            }
            print(
                "\(mode.rawValue), \(body.rawValue): "
                    + "\(total.early) posts returned before their number was handled (\(earlyConfigurations) of \(configurations) configurations); "
                    + "\(total.outOfOrder) numbers out of order; last number not handled in \(notLast) configurations; "
                    + "\(total.handled) numbers handled of \(posts * configurations) posted")
        }
    }
}

// MARK: - Case 1: a listener that never reads again

final class Gate: Sendable {
    private let state = Mutex<(open: Bool, waiter: CheckedContinuation<Void, Never>?)>((false, nil))

    nonisolated(nonsending) func wait() async {
        await withCheckedContinuation { continuation in
            let open = state.withLock { state in
                if state.open { return true }
                state.waiter = continuation
                return false
            }
            if open { continuation.resume() }
        }
    }

    func open() {
        let waiter = state.withLock { state in
            state.open = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume()
    }
}

actor Stuck {
    /// Handles the first number, then waits at the gate in its body, then reads on. With `leaveAfter`, it leaves
    /// its loop after that many numbers.
    func listen(_ hub: Hub, _ probe: Probe, _ gate: Gate, leaveAfter: Int?) async {
        for await number in hub.follow() {
            await probe.handle(number, .synchronous)
            if let leaveAfter, probe.count >= leaveAfter { break }
            if number == 1 { await gate.wait() }
        }
    }
}

/// Whether `operation` ends within `limit` seconds.
func ends(within limit: Double, _ operation: @escaping @Sendable () async -> Void) async -> (Bool, Task<Void, Never>) {
    let done = Atomic<Bool>(false)
    let task = Task.detached {
        await operation()
        done.store(true, ordering: .sequentiallyConsistent)
    }
    let deadline = seconds() + limit
    while !done.load(ordering: .sequentiallyConsistent) && seconds() < deadline { await Task.yield() }
    return (done.load(ordering: .sequentiallyConsistent), task)
}

func stuck() async {
    print("build: \(build)")
    for mode in Busy.allCases {
        // The listener handles number 1 and then stays in its body. It holds its iterator; it does not read.
        do {
            let hub = Hub()
            let probe = Probe()
            let gate = Gate()
            let actor = Stuck()
            let listener = Task.detached { await actor.listen(hub, probe, gate, leaveAfter: nil) }
            while hub.listeners < 1 { await Task.yield() }
            _ = await hub.post(mode)
            let (returned, post) = await ends(within: 1) { _ = await hub.post(mode) }
            print("\(mode.rawValue); the listener stays in its body and does not read:")
            print("  the second post \(returned ? "returned" : "did NOT return within 1 s"); the listener had handled \(probe.last) of 2")
            gate.open()
            await post.value
            let deadline = seconds() + 2
            while probe.last < 2 && seconds() < deadline { await Task.yield() }
            print("  after the listener read again: the post returned, and the listener handled \(probe.last) of 2")
            hub.finish()
            await listener.value
        }
        // The listener leaves its loop after number 1. Its iterator is gone.
        do {
            let hub = Hub()
            let probe = Probe()
            let gate = Gate()
            let actor = Stuck()
            let listener = Task.detached { await actor.listen(hub, probe, gate, leaveAfter: 1) }
            while hub.listeners < 1 { await Task.yield() }
            _ = await hub.post(mode)
            await listener.value
            let (returned, post) = await ends(within: 1) { for _ in 0..<1000 { _ = await hub.post(mode) } }
            print("\(mode.rawValue); the listener left its loop:")
            print("  1000 more posts \(returned ? "returned" : "did NOT return within 1 s")")
            hub.finish()
            await post.value
        }
        // The listener leaves its loop while a post waits for it.
        do {
            let hub = Hub()
            let probe = Probe()
            let gate = Gate()
            let actor = Stuck()
            let listener = Task.detached { await actor.listen(hub, probe, gate, leaveAfter: 2) }
            while hub.listeners < 1 { await Task.yield() }
            _ = await hub.post(mode)
            // The listener is at the gate. This post is number 2; the one after it finds the listener gone or busy.
            let (returnedBefore, post) = await ends(within: 0.3) {
                _ = await hub.post(mode)
                _ = await hub.post(mode)
            }
            gate.open()
            await listener.value
            let (returnedAfter, _) = await ends(within: 1) { await post.value }
            print("\(mode.rawValue); the listener handles one more number and leaves while posts wait:")
            print("  before it read again the posts \(returnedBefore ? "had returned" : "had not returned"); after it left they \(returnedAfter ? "returned" : "did NOT return within 1 s")")
            hub.finish()
        }
    }
}

// MARK: - Case 3: several listeners for one post

func many(_ count: Int, _ mode: Busy, _ body: Body, _ fanout: Fanout, posts: Int) async {
    let hub = Hub()
    let listeners = Listeners()
    var probes: [Probe] = []
    var tasks: [Task<Void, Never>] = []
    let kinds = Isolation.allCases
    let levels: [TaskPriority] = [.low, .high, .background, .medium]
    for index in 0..<count {
        let probe = Probe()
        probes.append(probe)
        tasks.append(listeners.start(kinds[index % kinds.count], hub, probe, body, priority: levels[index % levels.count]))
        // Registration order is the order of this loop.
        while hub.listeners < index + 1 { await Task.yield() }
    }
    let all = probes

    let start = seconds()
    let early = await withTaskGroup(of: Int.self) { group in
        for priority in [TaskPriority.high, .medium, .low, .background] {
            group.addTask(priority: priority) {
                var early = 0
                for _ in 0..<(posts / 4) {
                    let number = await hub.post(mode, fanout)
                    if all.contains(where: { $0.last < number }) { early += 1 }
                }
                return early
            }
        }
        var total = 0
        for await early in group { total += early }
        return total
    }
    let elapsed = seconds() - start

    let last = hub.posted
    let deadline = seconds() + 5
    while all.contains(where: { $0.last < last }) && seconds() < deadline { await Task.yield() }
    let notLast = all.filter { $0.last < last }.count
    let outOfOrder = all.reduce(0) { $0 + $1.outOfOrder }
    hub.finish()
    for task in tasks { await task.value }
    let microseconds = Int(elapsed / Double(posts) * 1e6)
    print(
        "  \(count) listeners, \(fanout.rawValue): \(early) posts returned before every listener had handled their number; "
            + "\(outOfOrder) numbers out of order; \(notLast) listeners without the last number; \(microseconds) µs per post")
}

func manyMatrix(posts: Int) async {
    print("build: \(build); posts per line: \(posts); listeners on the main actor, default actors and custom executors in turn, at four priorities; 4 posters at four priorities")
    for (mode, body) in [(Busy.latest, Body.synchronous), (.waits, .suspends), (.latest, .suspends)] {
        print("\(mode.rawValue), \(body.rawValue):")
        for count in [3, 8] {
            for fanout in Fanout.allCases { await many(count, mode, body, fanout, posts: posts) }
        }
    }
}

// MARK: - A loop body that awaits a post on the same hub

/// `posting` listeners whose body posts, `quiet` listeners whose body does not, and 4 posters outside. Every post
/// waits for a busy listener, and all handshakes go together. Returns nil when it did not end in `limit` seconds.
func reacting(
    posting: Int, quiet: Int, _ exempt: Exempt, posts: Int, limit: Double,
    postingBody: Body = .posts, quietBody: Body = .synchronous
) async -> String {
    let hub = Hub()
    let reaction = Reaction(hub: hub, exempt: exempt, limit: posts)
    let listeners = Listeners()
    let kinds = Isolation.allCases
    let levels: [TaskPriority] = [.low, .high, .background, .medium]
    let probes = Mutex<[Probe]>([])
    let tasks = Mutex<[Task<Void, Never>]>([])
    for index in 0..<(posting + quiet) {
        let probe = Probe(reaction: reaction)
        probes.withLock { $0.append(probe) }
        let body: Body = index < posting ? postingBody : quietBody
        let task = listeners.start(kinds[index % kinds.count], hub, probe, body, priority: levels[index % levels.count])
        tasks.withLock { $0.append(task) }
        while hub.listeners < index + 1 { await Task.yield() }
    }
    let all = probes.withLock { $0 }
    let outside = Atomic<Int>(0)
    let early = Atomic<Int>(0)

    let (ended, run) = await ends(within: limit) {
        await withTaskGroup(of: Void.self) { group in
            for priority in [TaskPriority.high, .medium, .low, .background] {
                group.addTask(priority: priority) {
                    while hub.posted < posts {
                        let number = await hub.post(.waits, .together, exempt: exempt)
                        outside.add(1, ordering: .sequentiallyConsistent)
                        if all.contains(where: { $0.last < number }) { early.add(1, ordering: .sequentiallyConsistent) }
                    }
                }
            }
        }
    }
    guard ended else {
        _ = run
        return "DID NOT END within \(Int(limit)) s: \(hub.posted) numbers posted, then every task waits"
    }
    let last = hub.posted
    let deadline = seconds() + 5
    while all.contains(where: { $0.last < last }) && seconds() < deadline { await Task.yield() }
    let notLast = all.filter { $0.last < last }.count
    let outOfOrder = all.reduce(0) { $0 + $1.outOfOrder }
    hub.finish()
    for task in tasks.withLock({ $0 }) { await task.value }
    return "ended; \(outside.load(ordering: .sequentiallyConsistent)) posts from outside, \(early.load(ordering: .sequentiallyConsistent)) of them returned before every listener had handled their number; "
        + "\(reaction.posts) posts from loop bodies, \(reaction.earlyPosts) of them returned before every other listener had handled their number; "
        + "\(outOfOrder) numbers out of order; \(notLast) listeners without the last number"
}

func ownMatrix(posts: Int) async {
    print("build: \(build); about \(posts) numbers per line; every post waits for a busy listener; all handshakes together")
    for exempt in Exempt.allCases {
        print("\(exempt.rawValue):")
        print("  1 listener whose body posts, 2 that do not: \(await reacting(posting: 1, quiet: 2, exempt, posts: posts, limit: 120))")
        print("  1 listener whose body posts, 7 that do not: \(await reacting(posting: 1, quiet: 7, exempt, posts: posts, limit: 120))")
        print("  1 listener whose body posts, alone: \(await reacting(posting: 1, quiet: 0, exempt, posts: posts, limit: 120))")
    }
}

func cross(posts: Int) async {
    print("build: \(build); about \(posts) numbers per line; every post waits for a busy listener; all handshakes together")
    for exempt in Exempt.allCases {
        print("\(exempt.rawValue):")
        print("  2 listeners whose bodies post, 1 that does not: \(await reacting(posting: 2, quiet: 1, exempt, posts: posts, limit: 20))")
        print("  3 listeners whose bodies post: \(await reacting(posting: 3, quiet: 0, exempt, posts: posts, limit: 20))")
    }
}

// MARK: - The decided rule: a post from a loop body waits for nobody

func bodyRule(posts: Int) async {
    print("build: \(build); about \(posts) numbers per line; a post from outside waits for every listener, all handshakes together; a post from a loop body waits for nobody")
    let lines: [(String, Int, Int, Body, Body)] = [
        ("1 listener whose body posts, 2 that do not", 1, 2, .posts, .synchronous),
        ("2 listeners whose bodies post, 1 that does not", 2, 1, .posts, .synchronous),
        ("3 listeners whose bodies post", 3, 0, .posts, .synchronous),
        ("8 listeners whose bodies post", 8, 0, .posts, .synchronous),
        ("2 listeners whose bodies post and suspend, 1 whose body suspends", 2, 1, .postsAndSuspends, .suspends),
        ("3 listeners whose bodies post and suspend", 3, 0, .postsAndSuspends, .synchronous),
        ("3 listeners whose bodies post and suspend, 5 whose bodies suspend", 3, 5, .postsAndSuspends, .suspends),
    ]
    for (name, posting, quiet, postingBody, quietBody) in lines {
        let result = await reacting(
            posting: posting, quiet: quiet, .body, posts: posts, limit: 120, postingBody: postingBody, quietBody: quietBody)
        print("  \(name): \(result)")
    }
}

// MARK: - A loop body that posts from a child task

final class Flag: Sendable {
    private let value = Atomic<Bool>(false)
    func set() { value.store(true, ordering: .sequentiallyConsistent) }
    var isSet: Bool { value.load(ordering: .sequentiallyConsistent) }
}

actor Parent {
    enum Child: String, Sendable, CaseIterable {
        case asyncLet = "async let, awaited"
        case group = "a task group child, awaited"
        case unstructuredAwaited = "Task { }, awaited"
        case unstructured = "Task { }, not awaited"
        case direct = "no child task (the body's own task)"
    }

    /// For number 1, the body posts once, in the given way. The post is number 2.
    func listen(_ hub: Hub, _ probe: Probe, _ child: Child, _ returned: Flag) async {
        for await number in hub.follow() {
            await probe.handle(number, .synchronous)
            guard number == 1 else { continue }
            switch child {
            case .asyncLet:
                async let posted = hub.post(.waits, .together, exempt: .body)
                _ = await posted
                returned.set()
            case .group:
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { _ = await hub.post(.waits, .together, exempt: .body) }
                }
                returned.set()
            case .unstructuredAwaited:
                await Task { _ = await hub.post(.waits, .together, exempt: .body) }.value
                returned.set()
            case .unstructured:
                Task {
                    _ = await hub.post(.waits, .together, exempt: .body)
                    returned.set()
                }
            case .direct:
                _ = await hub.post(.waits, .together, exempt: .body)
                returned.set()
            }
        }
    }
}

func child() async {
    print("build: \(build); 2 listeners; the body of the first posts once, for number 1; the rule is: a post from a loop body waits for nobody")
    for child in Parent.Child.allCases {
        let hub = Hub()
        let first = Probe()
        let second = Probe()
        let returned = Flag()
        let parent = Parent()
        let other = DefaultActor()
        let listener = Task.detached { await parent.listen(hub, first, child, returned) }
        while hub.listeners < 1 { await Task.yield() }
        let quiet = Task.detached { await other.listen(hub, second, .synchronous) }
        while hub.listeners < 2 { await Task.yield() }

        // Number 1, from outside. With an awaited child, the listener then never ends its body for number 1.
        let (outside, _) = await ends(within: 2) { _ = await hub.post(.waits, .together, exempt: .body) }
        let deadline = seconds() + 2
        while !(returned.isSet && first.last >= 2 && second.last >= 2) && seconds() < deadline {
            await Task.yield()
        }
        let posted = returned.isSet
        // One more post from outside: does the hub still work?
        let (next, _) = await ends(within: 2) { _ = await hub.post(.waits, .together, exempt: .body) }
        print("  \(child.rawValue): the first post from outside \(outside ? "returned" : "did NOT return"); the body's post \(posted ? "returned" : "did NOT return within 2 s"); "
            + "the posting listener handled \(first.last) and the other listener \(second.last) of \(hub.posted); a later post from outside \(next ? "returned" : "did NOT return within 2 s")")
        if posted && next {
            hub.finish()
            await listener.value
            await quiet.value
        }
    }
}

// MARK: - A listener that is cancelled while posts wait for it

actor Cancelled {
    enum Waits: Sendable {
        /// The body does not suspend: the listener waits in `next`.
        case inNext
        /// After number 1 the body sleeps. A sleep ends when its task is cancelled.
        case inASleep
        /// After number 1 the body waits at a gate, which does not know about cancellation.
        case atAGate(Gate)
        /// The body suspends for a moment after each number.
        case forAMoment
    }

    func listen(_ hub: Hub, _ probe: Probe, _ waits: Waits) async {
        for await number in hub.follow() {
            await probe.handle(number, .synchronous)
            switch waits {
            case .inNext: break
            case .inASleep: if number == 1 { try? await Task.sleep(for: .seconds(30)) }
            case .atAGate(let gate): if number == 1 { await gate.wait() }
            case .forAMoment: await Task.yield()
            }
        }
    }
}

func cancel(rounds: Int) async {
    print("build: \(build); every post waits for a busy listener; all handshakes together")

    // The listener waits in `next`, with no post in progress.
    do {
        let hub = Hub()
        let probe = Probe()
        let actor = Cancelled()
        let listener = Task.detached { await actor.listen(hub, probe, .inNext) }
        while hub.listeners < 1 { await Task.yield() }
        _ = await hub.post(.waits, .together)
        listener.cancel()
        let (ended, _) = await ends(within: 2) { await listener.value }
        let (returned, _) = await ends(within: 2) { for _ in 0..<1000 { _ = await hub.post(.waits, .together) } }
        print("cancelled while it waits in next: the listener's loop \(ended ? "ended" : "did NOT end"); 1000 more posts \(returned ? "returned" : "did NOT return within 2 s")")
    }

    // The listener is in its body, in a sleep, and a post waits for it.
    do {
        let hub = Hub()
        let probe = Probe()
        let actor = Cancelled()
        let listener = Task.detached { await actor.listen(hub, probe, .inASleep) }
        while hub.listeners < 1 { await Task.yield() }
        _ = await hub.post(.waits, .together)
        let (before, post) = await ends(within: 0.5) { _ = await hub.post(.waits, .together) }
        listener.cancel()
        let (after, _) = await ends(within: 2) { await post.value }
        print("cancelled while its body sleeps and a post waits: before the cancellation the post \(before ? "had returned" : "had not returned"); after it the post \(after ? "returned" : "did NOT return within 2 s"); the listener had handled \(probe.last) of 2")
        await listener.value
    }

    // The listener is in its body, at a gate that does not end on cancellation, and a post waits for it.
    do {
        let hub = Hub()
        let probe = Probe()
        let gate = Gate()
        let actor = Cancelled()
        let listener = Task.detached { await actor.listen(hub, probe, .atAGate(gate)) }
        while hub.listeners < 1 { await Task.yield() }
        _ = await hub.post(.waits, .together)
        let (_, post) = await ends(within: 0.3) { _ = await hub.post(.waits, .together) }
        listener.cancel()
        let (afterCancel, _) = await ends(within: 0.7) { await post.value }
        gate.open()
        let (afterBody, _) = await ends(within: 2) { await post.value }
        print("cancelled while its body waits for something that does not end on cancellation: after the cancellation the post \(afterCancel ? "returned" : "had not returned within 0.7 s"); after the body ended the post \(afterBody ? "returned" : "did NOT return within 2 s"); the listener had handled \(probe.last) of 2")
        await listener.value
    }

    // Many rounds: 3 listeners whose bodies suspend, 4 posters, and one listener is cancelled at some moment.
    do {
        var hung = 0
        var postsMade = 0
        for round in 0..<rounds {
            let hub = Hub()
            var probes: [Probe] = []
            var tasks: [Task<Void, Never>] = []
            for index in 0..<3 {
                let probe = Probe()
                let actor = Cancelled()
                probes.append(probe)
                tasks.append(Task.detached { await actor.listen(hub, probe, index == 0 ? .inNext : .forAMoment) })
                while hub.listeners < index + 1 { await Task.yield() }
            }
            let victim = tasks[round % 3]
            let survivors = probes.enumerated().filter { $0.offset != round % 3 }.map(\.element)
            let made = Atomic<Int>(0)
            let (ended, run) = await ends(within: 10) {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<4 {
                        group.addTask {
                            for _ in 0..<50 {
                                _ = await hub.post(.waits, .together)
                                made.add(1, ordering: .relaxed)
                            }
                        }
                    }
                    group.addTask {
                        for _ in 0..<(round % 40) { await Task.yield() }
                        victim.cancel()
                    }
                }
            }
            _ = run
            postsMade += made.load(ordering: .relaxed)
            if !ended { hung += 1; continue }
            _ = survivors
            hub.finish()
            for task in tasks { await task.value }
        }
        print("\(rounds) rounds, 3 listeners, 200 posts each round, one listener cancelled at a different moment each round: \(hung) rounds did not end within 10 s; \(postsMade) posts returned")
    }
}

@main
enum Cases {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()
        let posts = arguments.dropFirst().first.flatMap { Int($0) } ?? 20_000
        switch arguments.first {
        case "busy": await busyMatrix(posts: posts)
        case "stuck": await stuck()
        case "many": await manyMatrix(posts: posts)
        case "own": await ownMatrix(posts: posts)
        case "cross": await cross(posts: min(posts, 2000))
        case "cancel": await cancel(rounds: arguments.dropFirst().first.flatMap { Int($0) } ?? 2000)
        case "body": await bodyRule(posts: posts)
        case "child": await child()
        default: print("usage: cases busy|stuck|many|own|cross|cancel|body|child [posts]")
        }
    }
}
