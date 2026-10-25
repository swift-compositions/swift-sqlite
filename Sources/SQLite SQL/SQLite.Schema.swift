public import ISO_9075_Foundation
public import SQL
import SQL_Macros

extension SQLite {
    /// A row of the database's schema table, one per table, index, view and trigger.
    @Table("sqlite_schema")
    public struct Schema: Sendable {
        /// The kind of object: `table`, `index`, `view` or `trigger`.
        public let type: String

        /// The object's name.
        public let name: String

        /// The table the object belongs to; a table's own name for a table.
        @Column("tbl_name") public let table: String

        /// The page of the object's root b-tree, or 0 for views and triggers.
        @Column("rootpage") public let page: Int?

        /// The SQL that created the object, or none for an index SQLite created itself.
        public let sql: String?
    }
}

extension SQLite.Schema {
    /// Whether the schema has an object of `type` named `name`.
    public static func contains(_ type: String, named name: String) -> some Statement<Bool> {
        SQLQueryExpression<Bool>("SELECT \(Self.where { $0.type.eq(type) && $0.name.eq(name) }.exists())")
    }

    /// The number of objects in the schema that SQLite did not create for itself.
    public static var count: some Statement<Int> {
        Self.where { !$0.name.like("sqlite_%") }.count()
    }
}
