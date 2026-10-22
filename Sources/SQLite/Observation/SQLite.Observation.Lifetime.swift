#if Observation
    internal import GRDB

    extension SQLite.Observation {
        /// The database observation behind the sequence, cancelled when the last copy of the sequence or its iterator
        /// is gone.
        final class Lifetime: Sendable {
            let cancellable: AnyDatabaseCancellable?

            init(_ cancellable: AnyDatabaseCancellable?) {
                self.cancellable = cancellable
            }
        }
    }
#endif
