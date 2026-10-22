public import SQL

extension SQLite.Pragma {
    /// Controls whether all foreign-key constraints are deferred until commit.
    public enum DeferForeignKeys {}
}

extension SQLite.Pragma.DeferForeignKeys {
    /// A statement that reads whether all foreign-key constraints are deferred.
    public static var get: some Statement<Bool> {
        SQLQueryExpression("PRAGMA defer_foreign_keys")
    }

    /// Returns a statement that enables or disables deferral of all foreign-key constraints.
    ///
    /// SQLite resets this setting at each commit or rollback.
    public static func set(_ enabled: Bool) -> some Statement<()> {
        SQLQueryExpression("PRAGMA defer_foreign_keys = \(raw: enabled ? 1 : 0)")
    }
}
