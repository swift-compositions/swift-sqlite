// swift-sqlite#25, the three more cases, on the mechanism that holds (Holds.swift).
//
//   swiftc -swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault Cases.swift -o cases
//   ./cases busy 20000          case 1: a listener that is between two `next` calls when a post happens
//   ./cases stuck               case 1: a listener that never reads again
//   ./cases many 20000          case 3: several listeners for one post, one after another against together
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

        let value: Int? = await withCheckedContinuation { continuation in
            var released: [CheckedContinuation<Void, Never>] = []
            let ready: Int?? = state.withLock { state in
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
    func settle(_ published: Published, _ number: Int, _ busy: Busy, on actor: isolated any Actor) async {
        await withCheckedContinuation { (acknowledgement: CheckedContinuation<Void, Never>) in
            var waiter: CheckedContinuation<Int?, Never>?
            let wait: Bool = state.withLock { state in
                if state.gone || state.finished { return false }
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
                    state.acknowledgements.append((number, acknowledgement))
                    return true
                }
            }
            waiter?.resume(returning: number)
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
    nonisolated(nonsending) func post(_ busy: Busy, _ fanout: Fanout = .sequential) async -> Int {
        let (number, published) = state.withLock { state in
            state.posted += 1
            return (state.posted, state.subscriptions.map { ($0, $0.publish(state.posted)) })
        }
        switch fanout {
        case .sequential:
            for (subscription, published) in published {
                await subscription.settle(published, number, busy, on: subscription.isolation)
            }
        case .together:
            await withTaskGroup(of: Void.self) { group in
                for (subscription, published) in published {
                    group.addTask { await subscription.settle(published, number, busy, on: subscription.isolation) }
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
}

/// What one listener saw.
final class Probe: Sendable {
    private let seen = Atomic<Int>(0)
    private let disorder = Atomic<Int>(0)
    private let handled = Atomic<Int>(0)

    var last: Int { seen.load(ordering: .sequentiallyConsistent) }
    /// Numbers that came after a higher number.
    var outOfOrder: Int { disorder.load(ordering: .sequentiallyConsistent) }
    var count: Int { handled.load(ordering: .sequentiallyConsistent) }

    /// The body of the loop. Its synchronous part is the first two lines.
    nonisolated(nonsending) func handle(_ number: Int, _ body: Body) async {
        if number <= last { disorder.add(1, ordering: .sequentiallyConsistent) }
        seen.store(number, ordering: .sequentiallyConsistent)
        handled.add(1, ordering: .sequentiallyConsistent)
        if body == .suspends && number % 3 != 0 { await Task.yield() }
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

@main
enum Cases {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()
        let posts = arguments.dropFirst().first.flatMap { Int($0) } ?? 20_000
        switch arguments.first {
        case "busy": await busyMatrix(posts: posts)
        case "stuck": await stuck()
        case "many": await manyMatrix(posts: posts)
        default: print("usage: cases busy|stuck|many [posts]")
        }
    }
}
