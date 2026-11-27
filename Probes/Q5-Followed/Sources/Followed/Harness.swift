public import Executors
internal import Synchronization

/// What the listener's body writes and the writer reads after `await write`.
public final class Seen: Sendable {
    let value = Atomic<Int>(0)
    public init() {}
    public func record(_ seen: Int) { value.store(seen, ordering: .sequentiallyConsistent) }
    public var last: Int { value.load(ordering: .sequentiallyConsistent) }
}

/// The writer: an actor on a thread of its own, as in Q3-Actors. Commits are numbered in the order they happen.
public actor Writer {
    public nonisolated let executor: Kernel.Thread.Executor
    var commits = 0

    public init() { executor = Kernel.Thread.Executor() }

    public nonisolated var unownedExecutor: UnownedSerialExecutor { unsafe executor.asUnownedSerialExecutor() }

    func commit(to followed: Followed) -> (Int, (any Actor)?) {
        commits += 1
        return (commits, followed.publish(commits))
    }
}

public enum Wait: Swift.String, Sendable, CaseIterable {
    /// Resume the waiter, then await a job enqueued on the listener's isolation.
    case barrier
    /// Resume the waiter, then await the listener's request for the next element.
    case acknowledgement
    /// Resume the waiter and return: the control. The order must break here, or the test proves nothing.
    case nothing
}

/// `write`: hops to the writer, commits there, resumes the waiter there, comes back to the caller, and waits.
/// Returns the commit's number.
public nonisolated(nonsending) func write(_ writer: Writer, _ followed: Followed, wait: Wait) async -> Int {
    let (number, isolation) = await writer.commit(to: followed)
    switch wait {
    case .barrier: if let isolation { await barrier(on: isolation) }
    case .acknowledgement: await followed.acknowledged(number)
    case .nothing: break
    }
    return number
}

// The listeners: the body is `seen.record(value)`, with no suspension in it.

@MainActor
public func listenOnMain(_ followed: Followed, _ seen: Seen) async {
    for await value in followed { seen.record(value) }
}

public actor DefaultListener {
    public init() {}
    public func listen(_ followed: Followed, _ seen: Seen) async {
        for await value in followed { seen.record(value) }
    }
    public func noise() {}
}

public actor ThreadListener {
    public nonisolated let executor: Kernel.Thread.Executor
    public init() { executor = Kernel.Thread.Executor() }
    public nonisolated var unownedExecutor: UnownedSerialExecutor { unsafe executor.asUnownedSerialExecutor() }
    public func listen(_ followed: Followed, _ seen: Seen) async {
        for await value in followed { seen.record(value) }
    }
    public func noise() {}
}

/// A listener with no isolation: `next(isolation:)` records `nil`, and there is nothing to enqueue a job on.
@concurrent
public func listenNowhere(_ followed: Followed, _ seen: Seen) async {
    for await value in followed { seen.record(value) }
}

public enum Isolation: Swift.String, Sendable, CaseIterable {
    case main = "main actor"
    case `default` = "default actor"
    case thread = "thread executor"
    case none = "no isolation"
}

public struct Configuration: Sendable, CustomStringConvertible {
    public var isolation: Isolation
    public var listener: TaskPriority
    public var writers: TaskPriority
    /// Other tasks that keep the listener's executor busy, at every priority.
    public var noise: Bool
    public var wait: Wait

    public init(isolation: Isolation, listener: TaskPriority, writers: TaskPriority, noise: Bool, wait: Wait) {
        self.isolation = isolation
        self.listener = listener
        self.writers = writers
        self.noise = noise
        self.wait = wait
    }

    public var description: Swift.String {
        func name(_ priority: TaskPriority) -> Swift.String {
            switch priority {
            case .high: "high"
            case .medium: "medium"
            case .low: "low"
            case .background: "background"
            default: "\(priority.rawValue)"
            }
        }
        return "\(isolation.rawValue), listener \(name(listener)), writers \(name(writers)), "
            + "\(noise ? "busy" : "quiet"), wait: \(wait.rawValue)"
    }
}

/// Runs `writes` writes from four tasks at once and counts those after which the listener's body had not run for
/// the write's own commit: `seen < number` when `await write` returned.
public func breaks(_ configuration: Configuration, writes: Int) async -> Int {
    let followed = Followed()
    let seen = Seen()
    let writer = Writer()
    let stop = Atomic<Bool>(false)

    let main = configuration.isolation == .main
    let defaultListener = DefaultListener()
    let threadListener = ThreadListener()

    let listener: Task<Void, Never> =
        switch configuration.isolation {
        case .main: Task.detached(priority: configuration.listener) { await listenOnMain(followed, seen) }
        case .default: Task.detached(priority: configuration.listener) { await defaultListener.listen(followed, seen) }
        case .thread: Task.detached(priority: configuration.listener) { await threadListener.listen(followed, seen) }
        case .none: Task.detached(priority: configuration.listener) { await listenNowhere(followed, seen) }
        }
    while !followed.isFollowed { await Task.yield() }

    var noise: [Task<Void, Never>] = []
    if configuration.noise {
        for priority in [TaskPriority.high, .medium, .low, .background] {
            noise.append(
                Task.detached(priority: priority) {
                    while !stop.load(ordering: .relaxed) {
                        if main { await MainActor.run {} }
                        await defaultListener.noise()
                        await threadListener.noise()
                    }
                }
            )
        }
    }

    let tasks = 4
    let broken = await withTaskGroup(of: Int.self) { group in
        for _ in 0..<tasks {
            group.addTask(priority: configuration.writers) {
                var broken = 0
                for _ in 0..<(writes / tasks) {
                    let number = await write(writer, followed, wait: configuration.wait)
                    if seen.last < number { broken += 1 }
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
    followed.finish()
    await listener.value
    return broken
}
