internal import ISO_9075_Call_Level_Interface
internal import SQLite_SQL
internal import Synchronization

extension SQLite {
    /// The followed reads of one database. After each commit the writer reads every followed read again, on its own
    /// connection and so in commit order, and publishes the answers that changed. The write then waits until each
    /// listener has run its loop body for the answer, by a handshake on the listener's actor
    /// (swift-compositions/swift-sqlite#25).
    final class Hub: Sendable {
        private let state = Mutex(State())

        struct State {
            /// The number of the last publication. Each commit that is published gets the next one.
            var number = 0
            var followers: [any Follower] = []
        }

        /// What one commit published, for the wait that follows it.
        final class Receipt: Sendable {
            let hub: Hub
            private let settlements = Mutex<[any Settlement]>([])

            init(hub: Hub) { self.hub = hub }

            func add(_ settlement: any Settlement) { settlements.withLock { $0.append(settlement) } }

            func take() -> [any Settlement] {
                settlements.withLock { settlements in
                    defer { settlements = [] }
                    return settlements
                }
            }
        }
    }

    /// One followed read, with its value type erased.
    protocol Follower: AnyObject, Sendable {
        /// Reads again on the writer's connection and publishes the answer if it changed. Synchronous, and called in
        /// commit order.
        func refresh(on core: SQLite.Connection.Core, number: Int) -> (any Settlement)?
        /// Whether a write to `written` can have changed this follower's answer.
        func reads(_ written: SQLite.Region) -> Bool
        /// Whether `task` is the task of this follower's loop.
        func isListener(_ task: UInt) -> Bool
        var isGone: Bool { get }
    }

    /// One publication to one listener, to be settled after the commit.
    protocol Settlement: Sendable {
        /// Waits until the listener has run its body for the publication. Runs on the listener's actor.
        nonisolated(nonsending) func settle() async
        /// Gives the publication to the listener and does not wait for it.
        func deliver()
    }
}

extension SQLite.Hub {
    var isEmpty: Bool { state.withLock { $0.followers.isEmpty } }

    func add(_ follower: any SQLite.Follower) {
        state.withLock { $0.followers.append(follower) }
    }

    func remove(_ follower: any SQLite.Follower) {
        state.withLock { state in state.followers.removeAll { $0 === follower } }
    }

    /// Called by the writer, with its connection, after a commit.
    func publish(on core: SQLite.Connection.Core, into receipt: Receipt) {
        // A scope whose statements could write nothing left every answer as it was.
        let written = core.footprint.writes
        guard !written.isEmpty else { return }
        // A follower that reads none of the tables that were written keeps its answer and is not read.
        let (number, followers): (Int, [any SQLite.Follower]) = state.withLock { state in
            state.followers.removeAll { $0.isGone }
            let stale = state.followers.filter { $0.reads(written) }
            guard !stale.isEmpty else { return (0, []) }
            state.number += 1
            return (state.number, stale)
        }
        guard !followers.isEmpty else { return }
        // A followed read only reads: the writer's connection refuses a write for as long as they run.
        try? core.control("PRAGMA query_only = 1")
        for follower in followers {
            if let settlement = follower.refresh(on: core, number: number) { receipt.add(settlement) }
        }
        try? core.control("PRAGMA query_only = 0")
    }

    /// Called by `write` after its commit, on the caller's isolation.
    ///
    /// A write from anywhere but a listener's loop body returns when every listener has run its body for the answer
    /// the commit left, up to the body's first suspension. A write from inside a listener's loop body delivers to
    /// every listener and does not wait: two listeners that write in reaction to each other would wait for each other.
    nonisolated(nonsending) func settle(_ receipt: Receipt) async {
        let settlements = receipt.take()
        guard !settlements.isEmpty else { return }
        let task = SQLite.Hub.currentTask()
        let fromListener = state.withLock { state in state.followers.contains { $0.isListener(task) } }
        if fromListener {
            for settlement in settlements { settlement.deliver() }
        } else if settlements.count == 1 {
            await settlements[0].settle()
        } else {
            // All listeners together: each is served as soon as it reads.
            await withTaskGroup(of: Void.self) { group in
                for settlement in settlements { group.addTask { await settlement.settle() } }
            }
        }
    }

    /// The identity of the current task, to know a write that a listener's loop body makes. An address: it is an
    /// identity only while that task lives, and a listener's task lives while its loop runs. A body that writes from
    /// a child task is another task, and is not seen as the listener.
    static func currentTask() -> UInt {
        unsafe withUnsafeCurrentTask { task in unsafe task.map { unsafe unsafeBitCast($0, to: UInt.self) } ?? 0 }
    }
}

extension SQLite {
    /// One listener of one followed read: the latest answer it has not taken, and the writes that wait for it.
    final class Subscription<Value: Sendable>: Follower {
        typealias Element = Result<Value, ISO.`9075`.Error>

        /// An answer and the number of its publication.
        struct Delivery: Sendable {
            let number: Int
            let element: Element
        }

        /// The listener's actor, known from `observe` on.
        let isolation: any Actor
        let body: @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
        /// Whether two answers are the same, for a read whose equal answers yield nothing.
        let same: (@Sendable (Value, Value) -> Bool)?
        private let state: Mutex<State>

        struct State {
            /// The answer of the last publication, to compare the next with.
            var last: Value?
            /// The tables the read took its last answer from. Empty for a read that named none, such as one of a
            /// pragma: that one is read again after every write.
            var region: SQLite.Region
            /// The latest publication that the listener has not taken yet.
            var latest: (number: Int, element: Element)?
            /// The highest publication that the listener took.
            var taken = 0
            var waiter: CheckedContinuation<Delivery?, Never>?
            /// The waiter was taken out to be resumed, and its `next` is not yet back on the listener's actor.
            var transit = false
            /// Writes that wait, each until the listener has taken a publication that is not below `need`.
            var acknowledgements: [(need: Int, continuation: CheckedContinuation<Void, Never>)] = []
            var gone = false
            /// The task that iterates: the one that called `next` last.
            var task: UInt = 0
        }

        /// `first` is the answer at registration. With `yieldsFirst` it is the sequence's first element; without, the
        /// one that registers has it already, and the sequence starts at the next answer.
        init(
            isolation: any Actor,
            first: Value,
            region: SQLite.Region,
            yieldsFirst: Bool = true,
            same: (@Sendable (Value, Value) -> Bool)?,
            body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
        ) {
            self.isolation = isolation
            self.body = body
            self.same = same
            var state = State(region: region)
            state.last = first
            if yieldsFirst { state.latest = (0, .success(first)) }
            self.state = Mutex(state)
        }

        /// What `publish` found, for the wait that follows it.
        enum Published: Sendable {
            /// The listener waited for an answer. This continuation is its `next`.
            case waiter(CheckedContinuation<Delivery?, Never>)
            /// The listener did not wait. The answer is kept as the latest.
            case kept
        }

        struct Publication: SQLite.Settlement {
            let subscription: Subscription
            let published: Published
            let number: Int
            let element: Element

            nonisolated(nonsending) func settle() async {
                await subscription.settle(published, number, element, on: subscription.isolation)
            }

            func deliver() {
                if case .waiter(let waiter) = published {
                    waiter.resume(returning: subscription.isGone ? nil : Delivery(number: number, element: element))
                }
            }
        }
    }
}

// MARK: - The writer's side

extension SQLite.Subscription {
    var isGone: Bool { state.withLock { $0.gone } }

    func isListener(_ task: UInt) -> Bool {
        task != 0 && state.withLock { $0.task == task && !$0.gone }
    }

    func reads(_ written: SQLite.Region) -> Bool {
        state.withLock { $0.region.isEmpty || $0.region.intersects(written) }
    }

    func refresh(on core: SQLite.Connection.Core, number: Int) -> (any SQLite.Settlement)? {
        let (element, region): (Element, SQLite.Region) = core.measure {
            do throws(ISO.`9075`.Error) {
                return .success(try body(SQLite.Connection(core)))
            } catch {
                return .failure(error)
            }
        }
        let published: Published? = state.withLock { state in
            if state.gone { return nil }
            // A read that failed may have named fewer tables than it reads: it keeps the ones it had.
            if case .success = element { state.region = region } else { state.region.formUnion(region) }
            if case .success(let value) = element {
                if let last = state.last, let same, same(last, value) { return nil }
                state.last = value
            }
            if let waiter = state.waiter {
                state.waiter = nil
                state.transit = true
                return .waiter(waiter)
            }
            state.latest = (number, element)
            return .kept
        }
        return published.map { Publication(subscription: self, published: $0, number: number, element: element) }
    }

    /// Runs on the listener's actor, and returns on it. So it returns when no job of the listener runs there.
    private func settle(
        _ published: Published,
        _ number: Int,
        _ element: Element,
        on actor: isolated any Actor
    ) async {
        await withCheckedContinuation { (acknowledgement: CheckedContinuation<Void, Never>) in
            var waiter: CheckedContinuation<Delivery?, Never>?
            var answer: Delivery? = Delivery(number: number, element: element)
            let wait: Bool = state.withLock { state in
                if state.gone {
                    // The listener left, or was cancelled, after `refresh` took its waiter out. That waiter must
                    // still be resumed, by the one that holds it: here.
                    if case .waiter(let continuation) = published {
                        waiter = continuation
                        answer = nil
                    }
                    return false
                }
                switch published {
                case .waiter(let continuation):
                    // The handshake: the acknowledgement is stored before the listener is resumed.
                    waiter = continuation
                    state.acknowledgements.append((number, acknowledgement))
                    return true
                case .kept:
                    // The listener took this answer, or a later one, in a job that is over: this runs on its actor.
                    if state.taken >= number { return false }
                    // Otherwise the listener is on its way back to its actor, or its body has suspended: the write
                    // waits until it has taken this answer or a later one.
                    state.acknowledgements.append((number, acknowledgement))
                    return true
                }
            }
            waiter?.resume(returning: answer)
            if !wait { acknowledgement.resume() }
        }
    }
}

// MARK: - The listener's side

extension SQLite.Subscription {
    func next(isolation actor: isolated (any Actor)?) async -> Element? {
        // The function that gives out the sequence takes the listener's actor and the sequence is not Sendable, so
        // the compiler refuses a listener on another actor or on none. This is the last line of defence.
        guard actor === isolation else {
            leave()
            return .failure(.execution("a followed read was iterated off the actor that asked for it"))
        }
        // A cancelled listener is a listener that is gone: nothing may wait for it.
        if Task.isCancelled {
            leave()
            return nil
        }
        let task = SQLite.Hub.currentTask()

        let delivery: Delivery? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var released: [CheckedContinuation<Void, Never>] = []
                let ready: Delivery?? = state.withLock { state in
                    state.task = task
                    if state.gone { return .some(nil) }
                    if let latest = state.latest {
                        // Taken with no suspension: the body for it runs in the job that runs now.
                        state.latest = nil
                        state.taken = max(state.taken, latest.number)
                        released = Self.release(&state)
                        return .some(Delivery(number: latest.number, element: latest.element))
                    }
                    state.waiter = continuation
                    return nil
                }
                for acknowledgement in released { acknowledgement.resume() }
                if let ready { continuation.resume(returning: ready) }
            }
        } onCancel: {
            // Cancelled while it waits for an answer: the waiter gets `nil`, and the writes that wait go on.
            leave()
        }

        // Back on the listener's actor, which the listener keeps until its body suspends or asks for the next answer.
        // A write that is released now must get this actor to return, so it returns after the body.
        let released = state.withLock { state in
            state.transit = false
            if let delivery { state.taken = max(state.taken, delivery.number) }
            return Self.release(&state)
        }
        for acknowledgement in released { acknowledgement.resume() }
        if case .failure? = delivery?.element { leave() }
        return delivery?.element
    }

    private static func release(_ state: inout State) -> [CheckedContinuation<Void, Never>] {
        let done = state.acknowledgements.filter { $0.need <= state.taken }.map(\.continuation)
        state.acknowledgements.removeAll { $0.need <= state.taken }
        return done
    }

    /// The listener's sequence is gone, or its task was cancelled. Nobody may wait for this listener any more.
    func leave() {
        let (waiter, waiting) = state.withLock { state in
            state.gone = true
            defer {
                state.waiter = nil
                state.acknowledgements = []
            }
            return (state.waiter, state.acknowledgements.map(\.continuation))
        }
        waiter?.resume(returning: nil)
        for acknowledgement in waiting { acknowledgement.resume() }
    }
}
