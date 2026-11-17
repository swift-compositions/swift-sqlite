#if GRDB
    public import SQL
    import SQL_Test_Support
    public import SQLite
    public import Test

    extension Test::Test.Snapshot.Strategy where Format == Swift.String {
        /// The rows the statement returns when read from `database`, drawn as SQL Test Support's `.rows` draws them,
        /// with `drawing` first.
        @_disfavoredOverload
        public static func rows<each V: QueryRepresentable>(
            in database: SQLite.Database,
            drawing: @escaping (Any) -> Swift.String? = { _ in nil }
        ) -> Self
        where Value: SQL::Statement<(repeat each V)> {
            .rows({ statement in try database.read { try statement.fetch.all($0) } }, drawing: drawing)
        }

        /// The rows the statement returns when run in a write to `database`, such as an insert's `RETURNING` rows.
        @_disfavoredOverload
        public static func rows<each V: QueryRepresentable>(
            writing database: SQLite.Database,
            drawing: @escaping (Any) -> Swift.String? = { _ in nil }
        ) -> Self
        where Value: SQL::Statement<(repeat each V)> {
            .rows({ statement in try database.write { try statement.fetch.all($0) } }, drawing: drawing)
        }

        /// Every column of the selected tables, read from `database`.
        public static func rows<each J: SQL::Table>(
            in database: SQLite.Database,
            drawing: @escaping (Any) -> Swift.String? = { _ in nil }
        ) -> Self
        where Value: SelectStatement, Value.QueryValue == (), Value.Joins == (repeat each J) {
            .rows({ statement in try database.read { try statement.selectStar().fetch.all($0) } }, drawing: drawing)
        }

        /// Every column of the selected tables, read in a write to `database`.
        public static func rows<each J: SQL::Table>(
            writing database: SQLite.Database,
            drawing: @escaping (Any) -> Swift.String? = { _ in nil }
        ) -> Self
        where Value: SelectStatement, Value.QueryValue == (), Value.Joins == (repeat each J) {
            .rows({ statement in try database.write { try statement.selectStar().fetch.all($0) } }, drawing: drawing)
        }
    }
#endif
