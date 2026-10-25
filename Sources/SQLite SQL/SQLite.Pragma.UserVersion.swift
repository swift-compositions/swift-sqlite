public import SQL

extension SQLite.Pragma {
    /// An application-defined integer stored in the database header.
    public enum UserVersion {}
}

extension SQLite.Pragma.UserVersion {
    /// A statement that reads the application-defined version.
    public static var get: some Statement<Int> {
        SQLQueryExpression("PRAGMA user_version")
    }

    /// Returns a statement that writes the application-defined version.
    public static func set(_ version: Int) -> some Statement<()> {
        SQLQueryExpression("PRAGMA user_version = \(raw: version)")
    }
}
