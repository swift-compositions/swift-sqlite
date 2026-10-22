public import SQL

extension SQLite.Pragma {
    /// Controls enforcement of foreign-key constraints on a database connection.
    public enum ForeignKeys {}
}

extension SQLite.Pragma.ForeignKeys {
    /// A statement that reads whether foreign-key constraints are enforced.
    public static var get: some Statement<Bool> {
        SQLQueryExpression("PRAGMA foreign_keys")
    }

    /// Returns a statement that enables or disables foreign-key constraint enforcement.
    ///
    /// SQLite ignores changes to this setting while a transaction or savepoint is active.
    public static func set(_ enabled: Bool) -> some Statement<()> {
        SQLQueryExpression("PRAGMA foreign_keys = \(raw: enabled ? 1 : 0)")
    }
}
