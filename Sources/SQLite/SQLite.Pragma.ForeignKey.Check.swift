public import SQL
import SQL_Macros

extension SQLite.Pragma.ForeignKey {
    /// A foreign-key constraint violation in the current database.
    @Table
    public struct Check: Sendable {
        public static var tableAlias: String? { "foreignKeyChecks" }
        public static var tableFragment: ISO_9075.Fragment { "pragma_foreign_key_check()" }

        /// The child table containing the violation.
        public let table: String

        /// The row identifier of the violating child row.
        public let rowid: Int

        /// The referenced parent table.
        public let parent: String

        /// The violated constraint's index in the child table's foreign-key list.
        @Column("fkid") public let index: Int
    }
}
