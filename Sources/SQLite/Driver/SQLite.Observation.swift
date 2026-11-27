public import ISO_9075_Call_Level_Interface
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
