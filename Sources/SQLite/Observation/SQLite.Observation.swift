public import SQLite_SQL
#if Observation
    internal import GRDB

    extension SQLite {
        /// The answers a read gives over time: the answer when ``SQLite/Database/observe(_:)`` returned, then each
        /// answer a later committed write changes, in commit order. A write that leaves the answer equal yields nothing.
        ///
        /// A plain async sequence for one consumer. The observation ends when the iterating task is cancelled, or when
        /// the sequence and its iterator are gone.
        public struct Observation<Value: Sendable>: AsyncSequence, Sendable {
            let values: AsyncThrowingStream<Value, any Swift.Error>
            let cancellable: AnyDatabaseCancellable?

            init(_ values: AsyncThrowingStream<Value, any Swift.Error>, cancellable: AnyDatabaseCancellable?) {
                self.values = values
                self.cancellable = cancellable
            }
        }
    }

    extension SQLite.Observation {
        public func makeAsyncIterator() -> Iterator {
            Iterator(values.makeAsyncIterator(), cancellable: cancellable)
        }
    }
#endif
