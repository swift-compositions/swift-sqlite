#if GRDB
    /// What a caller's closure threw, carried unchanged through GRDB, which rolls back on it, to ``separating(_:)``.
    package struct Raised<Thrown: Swift.Error>: Swift.Error {
        package let thrown: Thrown

        package static func raising<T>(_ body: () throws(Thrown) -> T) throws(Raised) -> T {
            do {
                return try body()
            } catch {
                throw Raised(thrown: error)
            }
        }
    }
#endif
