// swift-sqlite#25: a post returns only after the listener of an async sequence has run its body for it.
//
// One file, no dependency. Build and run:
//
//   swiftc -swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault Spike.swift -o spike
//   ./spike log                 where the listener's task goes on resume, for each variation
//   ./spike matrix 20000        breaks per variation, isolation, poster, priority
//   ./spike regression          the check for swiftlang/swift#92915
//
// The listener is a `for await` loop whose body is synchronous: `seen.record(value)`. A poster calls
// `await channel.post()`, which returns the number of its value. A BREAK is a post that returned while the listener
// had not run its body for that number.

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Synchronization

// MARK: - Threads

func currentThread() -> UInt {
    #if canImport(Darwin)
    UInt(bitPattern: Int(bitPattern: pthread_self()))
    #else
    UInt(pthread_self())
    #endif
}

/// A serial executor on a thread of its own, first in, first out. It can log every enqueue.
final class ThreadExecutor: SerialExecutor, @unchecked Sendable {
    struct Enqueue: Sendable {
        var job: String
        var thread: UInt
    }

    private let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    private let condition = UnsafeMutablePointer<pthread_cond_t>.allocate(capacity: 1)
    private var jobs: [UnownedJob] = []
    private var head = 0
    private var log: [Enqueue]?
    private(set) var thread: UInt = 0

    init() {
        pthread_mutex_init(mutex, nil)
        pthread_cond_init(condition, nil)
        var handle: pthread_t?
        #if canImport(Darwin)
        typealias Argument = UnsafeMutableRawPointer
        #else
        typealias Argument = UnsafeMutableRawPointer?
        #endif
        let start: @convention(c) (Argument) -> UnsafeMutableRawPointer? = { raw in
            #if canImport(Darwin)
            let executor = Unmanaged<ThreadExecutor>.fromOpaque(raw).takeRetainedValue()
            #else
            let executor = Unmanaged<ThreadExecutor>.fromOpaque(raw!).takeRetainedValue()
            #endif
            executor.run()
            return nil
        }
        #if canImport(Darwin)
        pthread_create(&handle, nil, start, Unmanaged.passRetained(self).toOpaque())
        #else
        var created = pthread_t()
        pthread_create(&created, nil, start, Unmanaged.passRetained(self).toOpaque())
        handle = created
        #endif
        _ = handle
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        pthread_mutex_lock(mutex)
        log?.append(Enqueue(job: job.description, thread: currentThread()))
        jobs.append(job)
        pthread_cond_signal(condition)
        pthread_mutex_unlock(mutex)
    }

    private func run() {
        pthread_mutex_lock(mutex)
        thread = currentThread()
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

    func startLog() {
        pthread_mutex_lock(mutex)
        log = []
        pthread_mutex_unlock(mutex)
    }

    func takeLog() -> [Enqueue] {
        pthread_mutex_lock(mutex)
        defer {
            log = nil
            pthread_mutex_unlock(mutex)
        }
        return log ?? []
    }
}

// MARK: - The channel

enum Variation: String, CaseIterable, Sendable {
    /// The first probe: the poster resumes the waiter's continuation, then awaits a job on the listener's isolation.
    case baseline = "0 baseline: resume, then a job"
    /// Variation 1 of the issue: the poster hops to the listener's isolation and resumes there. No second job.
    case resumeThere = "1a resume on the listener's isolation"
    /// Variation 1, with the job after it.
    case resumeThereThenJob = "1b resume on the listener's isolation, then a job"
    /// Variation 2: the continuation is made in a function isolated to the listener, with the `isolation:` forms.
    case isolatedChecked = "2a withCheckedContinuation(isolation:)"
    case isolatedUnsafe = "2b withUnsafeContinuation(isolation:)"
    /// Variation 3: one job on the listener's isolation resumes the waiter and enqueues the second job from there.
    case oneHop = "3 one hop: resume there, and yield there"
    /// No continuation. The listener's pending `next` is a job that an executor holds. The poster runs that job to
    /// its hop back to the listener's isolation, and then enqueues its own job there.
    case heldJob = "5 held job: no continuation"
}

/// The state that the listener, the posters and the holding executor share.
final class Core: Sendable {
    enum Waiter {
        case checked(CheckedContinuation<Int?, Never>)
        case unsafe(UnsafeContinuation<Int?, Never>)

        func resume(returning value: Int?) {
            switch self {
            case .checked(let continuation): continuation.resume(returning: value)
            case .unsafe(let continuation): continuation.resume(returning: value)
            }
        }
    }

    /// Where the listener's pending `next` is, for the held job.
    enum Phase {
        /// The listener is not in `next`: it runs its body, or it is on its way to do so.
        case idle
        /// The listener found nothing and is on its way to the gate.
        case promised
        /// The listener's task is a job that the gate's executor holds.
        case held(UnownedJob)
        /// Someone runs the held job now. It is not yet back in the queue of the listener's isolation.
        case moving
    }

    struct State {
        var buffer: [Int] = []
        var posted = 0
        var isolation: (any Actor)?
        var listening = false
        var finished = false
        var waiter: Waiter?
        var phase = Phase.idle
        var arrivals: [CheckedContinuation<Void, Never>] = []
    }

    let state = Mutex(State())
    /// For the log: the thread that called `resume`, or that ran the held job.
    let resumer = Atomic<UInt>(0)
}

/// The executor of the gate. The only job it ever gets is the listener's call of `Gate.take()`.
final class HoldingExecutor: SerialExecutor, Sendable {
    let core: Core

    init(_ core: Core) { self.core = core }

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        let runNow = core.state.withLock { state in
            if state.buffer.isEmpty && !state.finished {
                state.phase = .held(job)
                return false
            }
            // A value came in while the listener was on its way here. Do not hold the job.
            state.phase = .moving
            return true
        }
        if runNow { release(job) }
    }

    /// Runs the listener's task from its arrival at the gate to its hop back to its own isolation. When this
    /// returns, the listener's task is in the queue of its isolation. Only then may a poster enqueue its job.
    func release(_ job: UnownedJob) {
        core.resumer.store(currentThread(), ordering: .sequentiallyConsistent)
        job.runSynchronously(on: asUnownedSerialExecutor())
        let arrivals = core.state.withLock { state in
            state.phase = .idle
            defer { state.arrivals = [] }
            return state.arrivals
        }
        for arrival in arrivals { arrival.resume() }
    }
}

actor Gate {
    nonisolated let executor: HoldingExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

    init(_ core: Core) { executor = HoldingExecutor(core) }

    /// Runs when the executor lets the job go: on a poster's thread, or on the listener's own.
    func take() -> Int? {
        executor.core.state.withLock { $0.buffer.isEmpty ? nil : $0.buffer.removeFirst() }
    }
}

/// The job on the listener's isolation: nothing, on that actor.
func barrier(on actor: isolated any Actor) {}

final class Channel: AsyncSequence, Sendable {
    typealias Element = Int
    typealias Failure = Never

    let variation: Variation
    let core = Core()
    let gate: Gate

    init(_ variation: Variation) {
        self.variation = variation
        self.gate = Gate(core)
    }

    func makeAsyncIterator() -> Iterator { Iterator(channel: self) }

    struct Iterator: AsyncIteratorProtocol {
        let channel: Channel

        mutating func next() async -> Int? {
            await channel.next(isolation: #isolation)
        }

        mutating func next(isolation actor: isolated (any Actor)?) async -> Int? {
            await channel.next(isolation: actor)
        }
    }

    var isFollowed: Bool { core.state.withLock { $0.listening } }

    // MARK: The listener's side

    func next(isolation actor: isolated (any Actor)?) async -> Int? {
        // A value that is already there is returned with no suspension: its body runs in the job that runs now.
        let ready: Int?? = core.state.withLock { state in
            state.isolation = actor
            state.listening = true
            if !state.buffer.isEmpty { return .some(state.buffer.removeFirst()) }
            if state.finished { return .some(nil) }
            if variation == .heldJob { state.phase = .promised }
            return nil
        }
        if let ready { return ready }

        switch variation {
        case .heldJob:
            // No continuation: a call to another actor. Its executor holds the job until a value is posted.
            return await gate.take()
        case .isolatedChecked:
            return await withCheckedContinuation(isolation: actor) { park(.checked($0)) }
        case .isolatedUnsafe:
            return await withUnsafeContinuation(isolation: actor) { park(.unsafe($0)) }
        default:
            return await withCheckedContinuation { park(.checked($0)) }
        }
    }

    private func park(_ waiter: Core.Waiter) {
        let ready: Int?? = core.state.withLock { state in
            if !state.buffer.isEmpty { return .some(state.buffer.removeFirst()) }
            if state.finished { return .some(nil) }
            state.waiter = waiter
            return nil
        }
        if let ready { waiter.resume(returning: ready) }
    }

    func finish() {
        let (waiter, job) = core.state.withLock { state -> (Core.Waiter?, UnownedJob?) in
            state.finished = true
            defer { state.waiter = nil }
            if case .held(let job) = state.phase {
                state.phase = .moving
                return (state.waiter, job)
            }
            return (state.waiter, nil)
        }
        waiter?.resume(returning: nil)
        if let job { gate.executor.release(job) }
    }

    // MARK: The poster's side

    /// Posts the next number and returns it when the listener has run its body for it. That is the claim.
    nonisolated(nonsending) func post() async -> Int {
        switch variation {
        case .baseline, .isolatedChecked, .isolatedUnsafe:
            let (number, isolation) = core.state.withLock { state in
                state.posted += 1
                if let waiter = state.waiter {
                    state.waiter = nil
                    core.resumer.store(currentThread(), ordering: .sequentiallyConsistent)
                    waiter.resume(returning: state.posted)
                } else {
                    state.buffer.append(state.posted)
                }
                return (state.posted, state.listening ? state.isolation : nil)
            }
            if let isolation { await job(on: isolation, from: #isolation) }
            return number

        case .resumeThere, .resumeThereThenJob, .oneHop:
            let (number, isolation) = core.state.withLock { state in
                state.posted += 1
                state.buffer.append(state.posted)
                return (state.posted, state.listening ? state.isolation : nil)
            }
            if let isolation {
                await resume(on: isolation, thenYield: variation == .oneHop)
                if variation == .resumeThereThenJob { await job(on: isolation, from: #isolation) }
            }
            return number

        case .heldJob:
            return await postToHeldJob()
        }
    }

    /// Variations 1 and 3: on the listener's isolation, hands the oldest value to the waiter.
    private func resume(on actor: isolated any Actor, thenYield: Bool) async {
        let resumed: (Core.Waiter, Int)? = core.state.withLock { state in
            guard let waiter = state.waiter, !state.buffer.isEmpty else { return nil }
            state.waiter = nil
            return (waiter, state.buffer.removeFirst())
        }
        if let (waiter, value) = resumed {
            core.resumer.store(currentThread(), ordering: .sequentiallyConsistent)
            waiter.resume(returning: value)
        }
        // Variation 3: the second job is enqueued from inside the actor.
        if thenYield { await Task.yield() }
    }

    /// The poster's job on the listener's isolation. When the poster is on that isolation already, a call to it does
    /// not suspend, so the poster leaves it and comes back.
    private nonisolated(nonsending) func job(on isolation: any Actor, from caller: (any Actor)?) async {
        if caller === isolation {
            await Task.yield()
        } else {
            await barrier(on: isolation)
        }
    }

    private nonisolated(nonsending) func postToHeldJob() async -> Int {
        enum Action {
            case nothing
            case release(UnownedJob, any Actor)
            case arrival(any Actor)
            case job(any Actor)
        }

        let (number, action) = core.state.withLock { state -> (Int, Action) in
            state.posted += 1
            state.buffer.append(state.posted)
            guard state.listening, let isolation = state.isolation else { return (state.posted, .nothing) }
            switch state.phase {
            case .held(let job):
                state.phase = .moving
                return (state.posted, .release(job, isolation))
            case .promised, .moving:
                return (state.posted, .arrival(isolation))
            case .idle:
                return (state.posted, .job(isolation))
            }
        }

        switch action {
        case .nothing:
            break
        case .release(let job, let isolation):
            // The listener's task runs here to its hop: after this line it is in its isolation's queue.
            gate.executor.release(job)
            await self.job(on: isolation, from: #isolation)
        case .arrival(let isolation):
            // The listener's task is between its isolation and the gate, or another poster runs it now. Wait until
            // it is back in its isolation's queue.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let held: UnownedJob?? = core.state.withLock { state in
                    switch state.phase {
                    case .idle:
                        return .some(nil)
                    case .held(let job):
                        state.phase = .moving
                        state.arrivals.append(continuation)
                        return .some(job)
                    case .promised, .moving:
                        state.arrivals.append(continuation)
                        return nil
                    }
                }
                switch held {
                case .some(.some(let job)): gate.executor.release(job)
                case .some(.none): continuation.resume()
                case .none: break
                }
            }
            await self.job(on: isolation, from: #isolation)
        case .job(let isolation):
            // The listener is in a job on its isolation, or its task is in that queue already.
            await self.job(on: isolation, from: #isolation)
        }
        return number
    }
}

// MARK: - Listeners and posters

final class Seen: Sendable {
    let value = Atomic<Int>(0)
    func record(_ seen: Int) { value.store(seen, ordering: .sequentiallyConsistent) }
    var last: Int { value.load(ordering: .sequentiallyConsistent) }
}

/// One post and its check, on the isolation of the caller. True is a break.
nonisolated(nonsending) func postAndCheck(_ channel: Channel, _ seen: Seen) async -> Bool {
    let number = await channel.post()
    return seen.last < number
}

@MainActor func listenOnMain(_ channel: Channel, _ seen: Seen) async {
    for await value in channel { seen.record(value) }
}

@MainActor func postOnMain(_ channel: Channel, _ seen: Seen) async -> Bool {
    await postAndCheck(channel, seen)
}

actor DefaultActor {
    func listen(_ channel: Channel, _ seen: Seen) async {
        for await value in channel { seen.record(value) }
    }
    func post(_ channel: Channel, _ seen: Seen) async -> Bool { await postAndCheck(channel, seen) }
    func noise() {}
}

actor ThreadActor {
    nonisolated let executor = ThreadExecutor()
    nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

    func listen(_ channel: Channel, _ seen: Seen) async {
        for await value in channel { seen.record(value) }
    }
    func post(_ channel: Channel, _ seen: Seen) async -> Bool { await postAndCheck(channel, seen) }
    func noise() {}
}

enum Isolation: String, CaseIterable, Sendable {
    case main = "main actor"
    case `default` = "default actor"
    case thread = "custom executor"
}

enum Poster: String, CaseIterable, Sendable {
    /// Four tasks with no isolation.
    case tasks = "4 tasks, no isolation"
    /// Four tasks that post from one other actor, which has a thread of its own, as a writer has.
    case actor = "4 tasks on another actor"
    /// Four tasks that post from the listener's own isolation.
    case same = "4 tasks on the listener's isolation"
}

struct Configuration: Sendable {
    var variation: Variation
    var isolation: Isolation
    var poster: Poster
    var listener: TaskPriority
    var posters: TaskPriority
    var busy: Bool
}

func name(_ priority: TaskPriority) -> String {
    switch priority {
    case .high: "high"
    case .medium: "medium"
    case .low: "low"
    case .background: "background"
    default: "\(priority.rawValue)"
    }
}

/// Runs `posts` posts and returns the number of breaks.
func breaks(_ configuration: Configuration, posts: Int) async -> Int {
    let channel = Channel(configuration.variation)
    let seen = Seen()
    let stop = Atomic<Bool>(false)
    let defaultActor = DefaultActor()
    let threadActor = ThreadActor()
    let other = ThreadActor()
    let isolation = configuration.isolation

    let listener = Task.detached(priority: configuration.listener) {
        switch isolation {
        case .main: await listenOnMain(channel, seen)
        case .default: await defaultActor.listen(channel, seen)
        case .thread: await threadActor.listen(channel, seen)
        }
    }
    while !channel.isFollowed { await Task.yield() }

    var noise: [Task<Void, Never>] = []
    if configuration.busy {
        for priority in [TaskPriority.high, .medium, .low, .background] {
            noise.append(
                Task.detached(priority: priority) {
                    while !stop.load(ordering: .relaxed) {
                        switch isolation {
                        case .main: await MainActor.run {}
                        case .default: await defaultActor.noise()
                        case .thread: await threadActor.noise()
                        }
                    }
                }
            )
        }
    }

    let poster = configuration.poster
    let tasks = 4
    let broken = await withTaskGroup(of: Int.self) { group in
        for _ in 0..<tasks {
            group.addTask(priority: configuration.posters) {
                var broken = 0
                for _ in 0..<(posts / tasks) {
                    let isBreak: Bool
                    switch (poster, isolation) {
                    case (.tasks, _): isBreak = await postAndCheck(channel, seen)
                    case (.actor, _): isBreak = await other.post(channel, seen)
                    case (.same, .main): isBreak = await postOnMain(channel, seen)
                    case (.same, .default): isBreak = await defaultActor.post(channel, seen)
                    case (.same, .thread): isBreak = await threadActor.post(channel, seen)
                    }
                    if isBreak { broken += 1 }
                }
                return broken
            }
        }
        var total = 0
        for await broken in group { total += broken }
        return total
    }

    stop.store(true, ordering: .relaxed)
    for task in noise { await task.value }
    channel.finish()
    await listener.value
    return broken
}

let priorities: [(TaskPriority, TaskPriority)] = [
    (.medium, .medium), (.low, .high), (.high, .low), (.background, .high), (.high, .background),
]

func matrix(posts: Int, only: Variation?) async {
    #if DEBUG
    let build = "debug"
    #else
    let build = "-O"
    #endif
    print("build: \(build); posts per configuration: \(posts)")
    for variation in Variation.allCases where only == nil || only == variation {
        var total = 0
        var brokenConfigurations = 0
        var configurations = 0
        var lines: [String] = []
        for isolation in Isolation.allCases {
            for poster in Poster.allCases {
                var cells: [String] = []
                for (listener, posters) in priorities {
                    for busy in [false, true] {
                        let broken = await breaks(
                            Configuration(
                                variation: variation, isolation: isolation, poster: poster, listener: listener,
                                posters: posters, busy: busy),
                            posts: posts)
                        total += broken
                        configurations += 1
                        if broken > 0 { brokenConfigurations += 1 }
                        cells.append("\(broken)")
                    }
                }
                lines.append("  \(isolation.rawValue) | \(poster.rawValue) | \(cells.joined(separator: " "))")
            }
        }
        print(
            "\(total == 0 ? "HOLDS " : "BREAKS") \(variation.rawValue): \(total) breaks, "
                + "\(brokenConfigurations) of \(configurations) configurations broken")
        print(
            "  columns: listener/posters priority "
                + priorities.map { "\(name($0.0))/\(name($0.1))" }.joined(separator: ", ") + "; each quiet, then busy")
        for line in lines { print(line) }
    }
}

// MARK: - The enqueue log

/// One post to a parked listener on an actor whose executor logs every enqueue. Shows where the listener's task
/// goes when it is resumed, and whether it is in the queue before the poster's job.
func log(_ variation: Variation) async {
    let channel = Channel(variation)
    let seen = Seen()
    let actor = ThreadActor()
    actor.executor.startLog()
    let listener = Task.detached { await actor.listen(channel, seen) }
    while !channel.isFollowed { await Task.yield() }
    // Let the listener park.
    try? await Task.sleep(for: .milliseconds(50))
    let listenerJob = actor.executor.takeLog().first?.job ?? "?"
    actor.executor.startLog()

    let poster = Task.detached { () -> (Bool, UInt) in
        let isBreak = await postAndCheck(channel, seen)
        return (isBreak, 0)
    }
    let (isBreak, _) = await poster.value
    try? await Task.sleep(for: .milliseconds(50))
    let entries = actor.executor.takeLog()
    let resumer = channel.core.resumer.load(ordering: .sequentiallyConsistent)

    print("\(variation.rawValue)")
    for (index, entry) in entries.enumerated() {
        let who = entry.job == listenerJob ? "the listener's task" : "the poster's task   "
        let from =
            entry.thread == resumer
            ? "the thread that resumed it"
            : entry.thread == actor.executor.thread ? "the listener's executor thread" : "another thread"
        print("  enqueue \(index + 1) on the listener's executor: \(who), from \(from)")
    }
    print("  when post returned, the listener's body had \(isBreak ? "NOT run: a break" : "run")")
    channel.finish()
    await listener.value
}

// MARK: - swiftlang/swift#92915

/// A generic actor whose method awaits `withTaskCancellationHandler { withCheckedContinuation }`. The report: in
/// `-O` on 6.4 the method goes on off the actor's executor after the await.
actor Generic<Value: Sendable> {
    var waiter: CheckedContinuation<Value, Never>?
    var offExecutor = 0

    nonisolated let executor = ThreadExecutor()
    nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

    func wait() async -> Value {
        let value = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Value, Never>) in
                waiter = continuation
            }
        } onCancel: {
        }
        if currentThread() != executor.thread { offExecutor += 1 }
        return value
    }

    func take() -> CheckedContinuation<Value, Never>? {
        defer { waiter = nil }
        return waiter
    }

    func count() -> Int { offExecutor }
}

func regression() async {
    let actor = Generic<Int>()
    let rounds = 20_000
    for round in 0..<rounds {
        let waiting = Task.detached { await actor.wait() }
        var waiter: CheckedContinuation<Int, Never>?
        while waiter == nil {
            waiter = await actor.take()
            if waiter == nil { await Task.yield() }
        }
        waiter?.resume(returning: round)
        _ = await waiting.value
    }
    let off = await actor.count()
    #if DEBUG
    let build = "debug"
    #else
    let build = "-O"
    #endif
    print("swiftlang/swift#92915, \(build): \(off) of \(rounds) resumptions went on off the actor's executor")
}

@main
enum Spike {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()
        switch arguments.first {
        case "log":
            for variation in Variation.allCases { await log(variation) }
        case "regression":
            await regression()
        default:
            let posts = arguments.dropFirst().first.flatMap { Int($0) } ?? 20_000
            let only = arguments.dropFirst(2).first.flatMap { prefix in
                Variation.allCases.first { $0.rawValue.hasPrefix(prefix) }
            }
            await matrix(posts: posts, only: only)
        }
    }
}
