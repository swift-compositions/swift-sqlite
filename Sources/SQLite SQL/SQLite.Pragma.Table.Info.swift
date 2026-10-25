public import SQL
import SQL_Macros

extension SQLite.Pragma.Table {
    /// A column in a table definition.
    @Table
    public struct Info<Base: SQL.Table> {
        public static var tableAlias: String? { "\(Base.tableName)TableInfo" }
        public static var schemaName: String? { Base.schemaName }
        public static var tableFragment: ISO_9075.Fragment {
            "pragma_table_info(\(text: Base.tableName))"
        }

        /// The column's rank within the table.
        @Column("cid") public let columnID: Int

        /// The column name.
        public let name: String

        /// The declared column type.
        public let type: String

        /// Whether the column has a `NOT NULL` constraint.
        @Column("notnull") public let isNotNull: Bool

        /// The column's default-value expression.
        @Column("dflt_value") public let defaultValue: String?

        /// Whether the column belongs to the primary key.
        @Column("pk") public let isPrimaryKey: Bool
    }
}
