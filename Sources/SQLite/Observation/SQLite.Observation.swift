#if Observation
    internal import GRDB
    public import ISO_9075_Call_Level_Interface

    extension SQLite {
        /// The answers a read gives over time: the answer when ``SQLite/Database/observe(_:)`` returned, then each
        /// answer a later committed write changes, in commit order. Writes that leave the answer equal yield nothing,
        /// and writes committed before the next answer is read may arrive as one answer.
        ///
        /// It is a plain async sequence for one consumer; the observation ends when the sequence and its iterator are
        /// gone, or when the iterating task is cancelled.
        public struct Observation<Value: Sendable>: AsyncSequence, Sendable {
            let values: AsyncThrowingStream<Value, any Swift.Error>
            let lifetime: Lifetime

            init(_ values: AsyncThrowingStream<Value, any Swift.Error>, lifetime: Lifetime) {
                self.values = values
                self.lifetime = lifetime
            }
        }
    }

    extension SQLite.Observation {
        public func makeAsyncIterator() -> Iterator {
            Iterator(values.makeAsyncIterator(), lifetime: lifetime)
        }
    }
#endif
