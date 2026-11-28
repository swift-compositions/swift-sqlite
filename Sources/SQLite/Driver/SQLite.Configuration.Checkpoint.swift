extension SQLite.Configuration {
    /// When the write-ahead log of a database with a file is copied back into the file.
    public enum Checkpoint: Sendable, Equatable {
        /// SQLite's own way: the write whose commit brings the log to `pages` pages copies it back before it
        /// returns. Zero never copies it back: the log then grows until something else checkpoints.
        case automatic(pages: Int)

        /// After a write has left the log at `pages` pages or more, a connection and a thread of their own copy the
        /// log back, while the writer goes on: no write waits for the copy. Under writes without a pause the copy may
        /// never reach the end of the log, so at `limit` pages the write that commits copies the log back before it
        /// returns, as ``automatic(pages:)`` does.
        /// The log of an attached database is copied back by the write that brings it to `pages` pages.
        case concurrent(pages: Int, limit: Int)
    }
}
