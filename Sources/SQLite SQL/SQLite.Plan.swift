public import ISO_9075_Foundation
public import SQL
import SQL_Macros

extension SQLite {
    /// A step of how SQLite will run a statement: a row of `EXPLAIN QUERY PLAN`.
    @Selection
    public struct Plan: Sendable, Equatable {
        /// The step's id.
        public let id: Int

        /// The id of the step this one is part of, or 0 for a top-level step.
        public let parent: Int

        /// A column SQLite reserves and leaves 0.
        @Column("notused") public let reserved: Int

        /// What the step does: `SCAN letter`, `SEARCH field USING INDEX …`, `USE TEMP B-TREE FOR ORDER BY`.
        public let detail: String
    }
}

extension SQLite.Plan {
    /// A statement that returns how SQLite will run `statement`, step by step, without running it.
    public static func of(_ statement: some Statement) -> some Statement<Self> {
        SQLQueryExpression<Self>("EXPLAIN QUERY PLAN \(statement.query)")
    }
}
