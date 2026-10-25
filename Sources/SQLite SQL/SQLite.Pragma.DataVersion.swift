public import SQL

extension SQLite.Pragma {
    /// A number that changes when another connection commits a change to the database file.
    public enum DataVersion {}
}

extension SQLite.Pragma.DataVersion {
    /// A statement that reads the data version as this connection sees it.
    public static var get: some Statement<Int> {
        SQLQueryExpression("PRAGMA data_version")
    }
}
