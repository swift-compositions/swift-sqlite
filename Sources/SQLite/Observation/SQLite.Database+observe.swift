public import SQLite_SQL
#if Observation
    internal import Dispatch
    internal import GRDB
    public import ISO_9075_Call_Level_Interface
    internal import Synchronization

    extension SQLite.Database {
        /// Follows the answer `body` reads: returns once the current answer is in, as the sequence's first element,
        /// or throws the error reading it gave.
        ///
        /// Every write committed after `observe` returns is observed: the sequence then yields the answer that write
        /// leaves, unless it equals the one before, so a test can write and then await the next element with no sleep
        /// or poll. What `body` read is tracked, and read again after each commit that touches it.
        public func observe<Value: Equatable & Sendable>(
            _ body: @escaping @Sendable (SQLite.Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> SQLite.Observation<Value> {
            let (values, continuation) = AsyncThrowingStream<Value, any Swift.Error>.makeStream()
            let first = Mutex<CheckedContinuation<ISO_9075.Error?, Never>?>(nil)
            var cancellable: AnyDatabaseCancellable?
            let failure = await withCheckedContinuation { (started: CheckedContinuation<ISO_9075.Error?, Never>) in
                first.withLock { $0 = started }
                cancellable =
                    ValueObservation
                    .tracking { database in try body(SQLite.Connection(database)) }
                    .removeDuplicates()
                    .start(
                        in: writer,
                        scheduling: .async(onQueue: DispatchQueue(label: "swift-sqlite.observation")),
                        onError: { error in
                            let error = ISO_9075.Error.observed(error)
                            continuation.finish(throwing: error)
                            first.withLock { $0.take() }?.resume(returning: error)
                        },
                        onChange: { value in
                            continuation.yield(value)
                            first.withLock { $0.take() }?.resume(returning: nil)
                        }
                    )
            }
            if let failure { throw failure }
            let observation = SQLite.Observation(values, cancellable: cancellable)
            continuation.onTermination = { [weak cancellable] _ in cancellable?.cancel() }
            return observation
        }
    }

    extension SQLite.Database {
        /// ``observe(_:)`` for a read that throws any error, as a typed statement's fetch does.
        @_disfavoredOverload
        public func observe<Value: Equatable & Sendable>(
            _ body: @escaping @Sendable (SQLite.Connection) throws -> Value
        ) async throws(ISO_9075.Error) -> SQLite.Observation<Value> {
            try await observe { (connection: SQLite.Connection) throws(ISO_9075.Error) -> Value in
                do {
                    return try body(connection)
                } catch {
                    throw .observed(error)
                }
            }
        }
    }

    extension ISO_9075.Error {
        fileprivate static func observed(_ error: any Swift.Error) -> Self {
            (error as? Self) ?? .execution("\(error)")
        }
    }
#endif
