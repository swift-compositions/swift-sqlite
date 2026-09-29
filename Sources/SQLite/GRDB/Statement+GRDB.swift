#if GRDB
    public import GRDB
    public import SQL

    extension SQL::Statement {
        @inlinable
        public func execute(_ db: GRDB.Database) throws where QueryValue == () {
            try QueryVoidCursor(db: db, query: query, cached: true).next()
        }

        @inlinable
        public func fetchAll(_ db: GRDB.Database) throws -> [QueryValue.QueryOutput]
        where QueryValue: QueryRepresentable {
            try Array(QueryValueCursor<QueryValue>(db: db, query: query, cached: true))
        }

        @inlinable
        public func fetchOne(_ db: GRDB.Database) throws -> QueryValue.QueryOutput?
        where QueryValue: QueryRepresentable {
            try QueryValueCursor<QueryValue>(db: db, query: query, cached: true).next()
        }

        @inlinable
        public func fetchCursor(_ db: GRDB.Database) throws -> QueryCursor<QueryValue.QueryOutput>
        where QueryValue: QueryRepresentable {
            try QueryValueCursor<QueryValue>(db: db, query: query, cached: false)
        }
    }

    extension SQL::Statement {
        @inlinable
        public func fetchAll<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> [(repeat (each Value).QueryOutput)]
        where QueryValue == (repeat each Value) {
            try Array(QueryPackCursor<repeat each Value>(db: db, query: query, cached: true))
        }

        @inlinable
        public func fetchOne<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> (repeat (each Value).QueryOutput)?
        where QueryValue == (repeat each Value) {
            try QueryPackCursor<repeat each Value>(db: db, query: query, cached: true).next()
        }

        @inlinable
        public func fetchCursor<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> QueryCursor<(repeat (each Value).QueryOutput)>
        where QueryValue == (repeat each Value) {
            try QueryPackCursor<repeat each Value>(db: db, query: query, cached: false)
        }
    }

    extension SelectStatement where QueryValue == (), Joins == () {
        @inlinable
        public func fetchCount(_ db: GRDB.Database) throws -> Int {
            try asSelect().count().fetchOne(db) ?? 0
        }

        @inlinable
        public func fetchAll(_ db: GRDB.Database) throws -> [From.QueryOutput] {
            try Array(QueryValueCursor<From>(db: db, query: query, cached: true))
        }

        @inlinable
        public func fetchOne(_ db: GRDB.Database) throws -> From.QueryOutput? {
            try QueryValueCursor<From>(db: db, query: asSelect().limit(1).query, cached: true).next()
        }

        @inlinable
        public func fetchCursor(_ db: GRDB.Database) throws -> QueryCursor<From.QueryOutput> {
            try QueryValueCursor<From>(db: db, query: query, cached: false)
        }
    }

    extension SQLite {
        public struct NotFound: Error, Hashable, Sendable {
            public init() {}
        }
    }

    extension SelectStatement where QueryValue == (), From: SQL::PrimaryKeyedTable, Joins == () {
        @inlinable
        public func find(
            _ db: GRDB.Database,
            key primaryKey: some QueryExpression<From.PrimaryKey>
        ) throws -> From.QueryOutput {
            guard let record = try asSelect().find(primaryKey).fetchOne(db) else {
                throw SQLite.NotFound()
            }
            return record
        }
    }

    extension SelectStatement where QueryValue == () {
        @inlinable
        public func fetchAll<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> [(From.QueryOutput, repeat (each J).QueryOutput)]
        where Joins == (repeat each J) {
            try Array(QueryPackCursor<From, repeat each J>(db: db, query: query, cached: true))
        }

        @inlinable
        public func fetchOne<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> (From.QueryOutput, repeat (each J).QueryOutput)?
        where Joins == (repeat each J) {
            try QueryPackCursor<From, repeat each J>(db: db, query: asSelect().limit(1).query, cached: true).next()
        }

        @inlinable
        public func fetchCursor<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> QueryCursor<(From.QueryOutput, repeat (each J).QueryOutput)>
        where Joins == (repeat each J) {
            try QueryPackCursor<From, repeat each J>(db: db, query: query, cached: false)
        }
    }
#endif
