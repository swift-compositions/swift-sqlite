public import SQLite_SQL
#if Observation
    internal import GRDB

    extension SQLite.Database {
        /// Yields once after each committed transaction that changes any of `tables`, until the stream ends. Changes that
        /// commit before the last one is consumed are one element, never one each.
        public func changes(to tables: [String]) -> AsyncStream<Void> {
            AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
                let observation = DatabaseRegionObservation(tracking: tables.map { GRDB.Table($0) })
                    .start(in: writer, onError: { _ in continuation.finish() }, onChange: { _ in continuation.yield(()) })
                continuation.onTermination = { _ in observation.cancel() }
            }
        }
    }
#endif
