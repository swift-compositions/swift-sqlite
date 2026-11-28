extension SQLite.Configuration {
    /// How much of a database one connection keeps in memory.
    public enum Cache: Sendable, Equatable {
        /// A number of pages.
        case pages(Int)
        /// A number of kibibytes, whatever the size of a page.
        case kibibytes(Int)
    }
}
