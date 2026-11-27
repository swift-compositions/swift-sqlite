public import ISO_9075_Call_Level_Interface
public import SQL
public import SQLite_SQL

extension SQLite {
    /// The answers a read gives over time: the answer when ``SQLite/Database/observe(isolation:_:)`` returned, then
    /// each answer a later committed write changes, in commit order. A write that leaves the answer equal yields
    /// nothing. A listener that is behind gets the latest answer, not each one in between.
    ///
    /// A sequence for one listener, on the actor that asked for it: it is not Sendable. The observation ends when the
    /// iterating task is cancelled, or when the sequence and its iterators are gone.
    public struct Observation<Value: Sendable>: AsyncSequence {
        public typealias Element = Value
        public typealias Failure = ISO.`9075`.Error

        let token: Token

        public func makeAsyncIterator() -> Iterator { Iterator(token: token) }

        public struct Iterator: AsyncIteratorProtocol {
            let token: Token

            public mutating func next() async throws(ISO.`9075`.Error) -> Value? {
                try await token.subscription.next(isolation: #isolation)?.get()
            }

            public mutating func next(isolation actor: isolated (any Actor)?) async throws(ISO.`9075`.Error) -> Value? {
                try await token.subscription.next(isolation: actor)?.get()
            }
        }

        /// Lives as long as the sequence and its iterators. Not Sendable, which keeps the sequence on its actor.
        final class Token {
            let lease: Lease

            var subscription: SQLite.Subscription<Value> { lease.subscription }

            init(_ subscription: SQLite.Subscription<Value>, hub: SQLite.Hub) {
                self.lease = Lease(subscription, hub: hub)
            }
        }

        /// The registration of one followed read: it ends when this is gone.
        final class Lease: Sendable {
            let subscription: SQLite.Subscription<Value>
            let hub: SQLite.Hub

            init(_ subscription: SQLite.Subscription<Value>, hub: SQLite.Hub) {
                self.subscription = subscription
                self.hub = hub
            }

            deinit {
                subscription.leave()
                hub.remove(subscription)
            }
        }
    }
}

extension SQLite.Database {
    /// Follows the answer `body` reads: returns once the current answer is in, as the sequence's first element, or
    /// throws the error reading it gave.
    ///
    /// Every write committed after `observe` returns is observed. A ``write(_:)`` returns when each listener has run
    /// its loop body for the answer the write left, up to the body's first suspension; so after `await write`, what
    /// the listeners show is what was written. A write made from inside a listener's loop body does not wait for the
    /// listeners. A listener is on an actor: a caller on none does not compile.
    ///
    /// `body` runs again on the writer after every commit, and must only read.
    public func observe<Value: Equatable & Sendable>(
        isolation: isolated any Actor = #isolation,
        _ body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> SQLite.Observation<Value> {
        try await follow(isolation: isolation, same: { $0 == $1 }, body)
    }

    /// ``observe(isolation:_:)`` for answers that are not compared: `same` is `nil`, and every commit yields.
    func follow<Value: Sendable>(
        isolation: isolated any Actor = #isolation,
        same: (@Sendable (Value, Value) -> Bool)?,
        _ body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> SQLite.Observation<Value> {
        let hub = hub
        let listener: any Actor = isolation
        // On the writer, so no commit falls between the first answer and the registration.
        let subscription: SQLite.Subscription<Value>
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            subscription = try await writer.run(.guardedRead) {
                (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> SQLite.Subscription<Value> in
                let subscription = SQLite.Subscription(
                    isolation: listener, first: try body(connection), same: same, body: body)
                hub.add(subscription)
                return subscription
            }
        } catch {
            throw error.error
        }
        return SQLite.Observation(token: SQLite.Observation.Token(subscription, hub: hub))
    }
}

// MARK: - The first answer apart

extension SQLite.Database {
    /// Follows `body` for a listener that takes the first answer itself: returns the answer at registration, and a
    /// sequence of the answers after it. The listener's value is then in before its loop has run.
    func following<Value: Sendable>(
        isolation: isolated any Actor = #isolation,
        same: (@Sendable (Value, Value) -> Bool)?,
        _ body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> (first: Value, later: SQLite.Observation<Value>) {
        let hub = hub
        let listener: any Actor = isolation
        let registered: Registered<Value>
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            registered = try await writer.run(.guardedRead) {
                (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Registered<Value> in
                try Registered(hub: hub, listener: listener, same: same, body: body, on: connection)
            }
        } catch {
            throw error.error
        }
        return (registered.first, SQLite.Observation(token: SQLite.Observation.Token(registered.subscription, hub: hub)))
    }

    /// ``following(isolation:same:_:)`` for code with no asynchronous context, for a listener on `listener`. It runs
    /// on the writer's connection, on the caller's thread, and waits behind a lock for a write that is running.
    ///
    /// Do not call it from the body of a read or write of the same database: it would wait for itself.
    func following<Value: Sendable>(
        on listener: any Actor,
        same: (@Sendable (Value, Value) -> Bool)?,
        _ body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
    ) throws(ISO.`9075`.Error) -> (first: Value, later: SQLite.Observation<Value>) {
        let hub = hub
        let registered: Registered<Value>
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            registered = try writer.slot.run(.guardedRead) {
                (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Registered<Value> in
                try Registered(hub: hub, listener: listener, same: same, body: body, on: connection)
            }
        } catch {
            throw error.error
        }
        return (registered.first, SQLite.Observation(token: SQLite.Observation.Token(registered.subscription, hub: hub)))
    }

    /// A followed read that is registered, and the answer it had then. Made on the writer, so that no commit falls
    /// between the answer and the registration.
    struct Registered<Value: Sendable>: Sendable {
        let first: Value
        let subscription: SQLite.Subscription<Value>

        init(
            hub: SQLite.Hub,
            listener: any Actor,
            same: (@Sendable (Value, Value) -> Bool)?,
            body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value,
            on connection: borrowing SQLite.Connection
        ) throws(ISO.`9075`.Error) {
            let first = try body(connection)
            self.first = first
            self.subscription = SQLite.Subscription(
                isolation: listener, first: first, yieldsFirst: false, same: same, body: body)
            hub.add(subscription)
        }
    }
}

// MARK: - A database that follows a read

extension SQLite.Database: FollowingDatabase {
    public func follow<Value: Equatable & Sendable>(
        on isolation: isolated any Actor,
        _ body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> FollowedRead<Value> {
        // The registration lasts as long as the sequence that holds this closure, which is not Sendable.
        let lease = try await follow(isolation: isolation, same: { $0 == $1 }, body).token.lease
        // The engine's own `next`, in the task that iterates and on its actor: the hub knows the listener by both.
        return FollowedRead { (actor: isolated (any Actor)?) async throws(ISO.`9075`.Error) -> Value? in
            try await lease.subscription.next(isolation: actor)?.get()
        }
    }
}
