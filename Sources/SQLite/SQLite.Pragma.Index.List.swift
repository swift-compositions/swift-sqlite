public import SQL
import SQL_Macros

extension SQLite.Pragma.Index {
    /// An index associated with a table.
    @Table
    public struct List<Base: SQL.Table> {
        public static var tableAlias: String? { "\(Base.tableName)Indices" }
        public static var tableFragment: ISO_9075.Fragment {
            "pragma_index_list(\(text: Base.tableName))"
        }

        /// The index's position in SQLite's result.
        @Column("seq") public let sequence: Int

        /// The index name.
        public let name: String

        /// Whether the index enforces uniqueness.
        @Column("unique") public let isUnique: Bool

        /// How the index was created.
        public let origin: String

        /// Whether the index has a `WHERE` clause.
        @Column("partial") public let isPartial: Bool
    }
}
