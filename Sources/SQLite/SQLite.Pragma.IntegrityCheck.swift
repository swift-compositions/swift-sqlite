public import SQL

extension SQLite.Pragma {
    /// Checks a database's low-level formatting and consistency.
    public enum IntegrityCheck {}
}

extension SQLite.Pragma.IntegrityCheck {
    /// A statement that returns each detected problem, or a single `"ok"` row when none are found.
    ///
    /// This check does not report foreign-key violations.
    public static var get: some Statement<String> {
        SQLQueryExpression("PRAGMA integrity_check")
    }
}
