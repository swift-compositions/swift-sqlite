public import SQL

extension SQLite.Pragma {
    /// Checks a database's low-level consistency without verifying UNIQUE constraints or index contents.
    public enum QuickCheck {}
}

extension SQLite.Pragma.QuickCheck {
    /// A statement that returns each detected problem, or a single `"ok"` row when none are found.
    public static var get: some Statement<String> {
        SQLQueryExpression("PRAGMA quick_check")
    }
}
