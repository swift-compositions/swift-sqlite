public import SQL
import SQL_Macros

extension SQLite.Pragma.ForeignKey {
    /// A foreign-key constraint declared by a table.
    @Table
    public struct List<Base: SQL.Table> {
        public static var tableAlias: String? { "\(Base.tableName)ForeignKeys" }
        public static var tableFragment: ISO_9075.Fragment {
            "pragma_foreign_key_list(\(text: Base.tableName))"
        }

        /// The constraint's identifier.
        public let id: Int

        /// The column's position within a composite constraint.
        @Column("seq") public let sequence: Int

        /// The referenced table.
        public let table: String

        /// The child column.
        public let from: String

        /// The referenced parent column.
        public let to: String

        /// The action performed when the parent column is updated.
        @Column("on_update") public let onUpdate: Action

        /// The action performed when the parent row is deleted.
        @Column("on_delete") public let onDelete: Action

        /// The constraint's match clause.
        public let match: String
    }
}
