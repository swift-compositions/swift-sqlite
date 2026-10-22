public import SQL
import SQL_Macros

extension SQLite.Pragma.Database {
    /// A row describing a database attached to the current connection.
    @Table
    public struct List {
        public static var tableAlias: String? { "databases" }
        public static var tableFragment: ISO_9075.Fragment { "pragma_database_list()" }

        /// The database's position in the connection's attached-database list.
        @Column("seq") public let sequence: Int

        /// The database's schema name.
        public let name: String

        /// The path to the database file, or an empty string for an in-memory database.
        public let file: String
    }
}
