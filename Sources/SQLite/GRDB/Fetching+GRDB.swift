public import SQLite_SQL
#if GRDB
    package import Cardinal
    package import GRDB
    public import ISO_9075_Call_Level_Interface
    public import SQL

    extension Fetching where Base: SQL::Statement, Base.QueryValue: QueryRepresentable {
        package func all(_ db: GRDB.Database) throws -> [Base.QueryValue.QueryOutput] {
            try Array(QueryValueCursor<Base.QueryValue>(db: db, query: base.query, cached: true))
        }

        package func one(_ db: GRDB.Database) throws -> Base.QueryValue.QueryOutput? {
            try QueryValueCursor<Base.QueryValue>(db: db, query: base.query, cached: true).next()
        }
    }

    extension Fetching where Base: SQL::Statement {
        package func all<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> [(repeat (each Value).QueryOutput)]
        where Base.QueryValue == (repeat each Value) {
            try Array(QueryPackCursor<repeat each Value>(db: db, query: base.query, cached: true))
        }

        package func one<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> (repeat (each Value).QueryOutput)?
        where Base.QueryValue == (repeat each Value) {
            try QueryPackCursor<repeat each Value>(db: db, query: base.query, cached: true).next()
        }
    }

    extension Fetching where Base: SelectStatement, Base.QueryValue == (), Base.Joins == () {
        package func count(_ db: GRDB.Database) throws -> Cardinal {
            let rows = try base.asSelect().count().fetch.one(db) ?? 0
            do throws(Cardinal.Error) {
                return try Cardinal(rows)
            } catch {
                throw ISO_9075.Error.decoding("a row count of \(rows) is no cardinal: \(error)")
            }
        }

        package func all(_ db: GRDB.Database) throws -> [Base.From.QueryOutput] {
            try Array(QueryValueCursor<Base.From>(db: db, query: base.query, cached: true))
        }

        package func one(_ db: GRDB.Database) throws -> Base.From.QueryOutput? {
            try QueryValueCursor<Base.From>(db: db, query: base.asSelect().limit(1).query, cached: true).next()
        }
    }

    extension Fetching where Base: SelectStatement, Base.QueryValue == () {
        package func all<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> [(Base.From.QueryOutput, repeat (each J).QueryOutput)]
        where Base.Joins == (repeat each J) {
            try Array(QueryPackCursor<Base.From, repeat each J>(db: db, query: base.query, cached: true))
        }

        package func one<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> (Base.From.QueryOutput, repeat (each J).QueryOutput)?
        where Base.Joins == (repeat each J) {
            try QueryPackCursor<Base.From, repeat each J>(db: db, query: base.asSelect().limit(1).query, cached: true).next()
        }
    }
#endif
