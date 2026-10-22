#if Observation
    public import GRDB
    public import ISO_9075_Call_Level_Interface

    extension SQLite.Database {
        // RED STAND-IN: today's Laurie path (ValueObservation.values(in:) erased to a stream); replaced in the next commit.
        public func observe<Value: Equatable & Sendable>(
            _ body: @escaping @Sendable (SQLite.Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> SQLite.Observation<Value> {
            let writer = writer
            let values = AsyncThrowingStream<Value, any Swift.Error> { continuation in
                let task = Task {
                    do {
                        for try await value in ValueObservation.tracking({ database in try body(SQLite.Connection(database)) })
                            .removeDuplicates().values(in: writer)
                        {
                            continuation.yield(value)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
            return SQLite.Observation(values, lifetime: SQLite.Observation.Lifetime(nil))
        }
    }
#endif
