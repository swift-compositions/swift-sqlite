internal import Synchronization

/// A followed read, reduced to what the order depends on: the commits of a writer as an `AsyncSequence` of their
/// numbers, whose iterator records the isolation of the listener that awaits it.
public final class Followed: AsyncSequence, Sendable {
    public typealias Element = Int
    public typealias Failure = Never

    struct State {
        var buffer: [Int] = []
        var waiter: CheckedContinuation<Int?, Never>?
        var isolation: (any Actor)?
        var listening = false
        var finished = false
        /// The number of the last element whose body is over: the listener asked for the one after it.
        var consumed = 0
        var delivered = 0
        var acknowledgements: [(upTo: Int, CheckedContinuation<Void, Never>)] = []
    }

    let state = Mutex(State())

    public init() {}

    public func makeAsyncIterator() -> Iterator { Iterator(followed: self, token: Token(self)) }

    /// Lives as long as the listener's iterator. When the listener leaves its loop, no write may wait for it.
    final class Token: Sendable {
        let followed: Followed
        init(_ followed: Followed) { self.followed = followed }
        deinit { followed.abandon() }
    }

    public struct Iterator: AsyncIteratorProtocol {
        let followed: Followed
        let token: Token

        public mutating func next() async -> Int? {
            await followed.take(isolation: #isolation)
        }

        public mutating func next(isolation actor: isolated (any Actor)?) async -> Int? {
            await followed.take(isolation: actor)
        }
    }

    /// The listener's side. Records the isolation it was called on. An element that is already there is returned
    /// with no suspension, so the listener's body for it runs in the job that is running now.
    func take(isolation actor: isolated (any Actor)?) async -> Int? {
        await withTaskCancellationHandler {
            await park(isolation: actor)
        } onCancel: {
            abandon()
        }
    }

    func park(isolation actor: isolated (any Actor)?) async -> Int? {
        await withCheckedContinuation { continuation in
            let ready: Int?? = state.withLock { state in
                state.isolation = actor
                state.listening = true
                // Asking for the next element says that the body of every element delivered so far is over.
                state.consumed = state.delivered
                let (done, waiting) = (
                    state.acknowledgements.filter { $0.upTo <= state.consumed },
                    state.acknowledgements.filter { $0.upTo > state.consumed }
                )
                state.acknowledgements = waiting
                for (_, acknowledgement) in done { acknowledgement.resume() }

                if !state.buffer.isEmpty {
                    let value = state.buffer.removeFirst()
                    state.delivered = value
                    return .some(value)
                }
                if state.finished || Task.isCancelled { return .some(nil) }
                state.waiter = continuation
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }
    }

    /// Whether a listener awaits an element, or awaited one before.
    public var isFollowed: Bool { state.withLock { $0.listening } }

    /// The listener is gone: its iterator was dropped, or its task was cancelled. Writes that wait for it go on.
    func abandon() {
        let (waiter, acknowledgements) = state.withLock { state in
            state.listening = false
            state.isolation = nil
            defer { state.waiter = nil; state.acknowledgements = [] }
            return (state.waiter, state.acknowledgements)
        }
        waiter?.resume(returning: nil)
        for (_, acknowledgement) in acknowledgements { acknowledgement.resume() }
    }

    public func finish() {
        let (waiter, acknowledgements) = state.withLock { state in
            state.finished = true
            defer { state.waiter = nil; state.acknowledgements = [] }
            return (state.waiter, state.acknowledgements)
        }
        waiter?.resume(returning: nil)
        for (_, acknowledgement) in acknowledgements { acknowledgement.resume() }
    }
}

extension Followed {
    /// The writer's side, called on the writer after its commit: resumes the waiter, or keeps the element for it.
    /// Returns the isolation the listener was last seen on.
    public func publish(_ value: Int) -> (any Actor)? {
        state.withLock { state in
            if let waiter = state.waiter {
                state.waiter = nil
                state.delivered = value
                waiter.resume(returning: value)
            } else {
                state.buffer.append(value)
            }
            return state.listening ? state.isolation : nil
        }
    }

    /// The other way to wait: until the listener asks for the element after `value`, which it does when its body for
    /// `value` is over. It depends on no executor's order.
    public func acknowledged(_ value: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let done = state.withLock { state in
                if state.consumed >= value || state.finished || !state.listening { return true }
                state.acknowledgements.append((value, continuation))
                return false
            }
            if done { continuation.resume() }
        }
    }
}

/// The job enqueued on the listener's isolation: nothing, on that actor.
public func barrier(on actor: isolated any Actor) {}
