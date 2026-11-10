public import SQLite_SQL
#if GRDB
    package import GRDB
    public import ISO_9075_Call_Level_Interface
    public import SQL

    extension SQL::Statement {
        public func fetchCursor(_ connection: SQLite.Connection) throws(ISO_9075.Error) -> QueryCursor<QueryValue.QueryOutput>
        where QueryValue: QueryRepresentable {
            try performing { try fetchCursor(connection.database) }
        }

        package func execute(_ db: GRDB.Database) throws where QueryValue == () {
            try QueryVoidCursor(db: db, query: query, cached: true).next()
        }

        package func fetchAll(_ db: GRDB.Database) throws -> [QueryValue.QueryOutput]
        where QueryValue: QueryRepresentable {
            try Array(QueryValueCursor<QueryValue>(db: db, query: query, cached: true))
        }

        package func fetchOne(_ db: GRDB.Database) throws -> QueryValue.QueryOutput?
        where QueryValue: QueryRepresentable {
            try QueryValueCursor<QueryValue>(db: db, query: query, cached: true).next()
        }

        package func fetchCursor(_ db: GRDB.Database) throws -> QueryCursor<QueryValue.QueryOutput>
        where QueryValue: QueryRepresentable {
            QueryCursor(try QueryValueCursor<QueryValue>(db: db, query: query, cached: false))
        }
    }

    extension SQL::Statement {
        public func fetchCursor<each Value: QueryRepresentable>(
            _ connection: SQLite.Connection
        ) throws(ISO_9075.Error) -> QueryCursor<(repeat (each Value).QueryOutput)>
        where QueryValue == (repeat each Value) {
            try performing { try fetchCursor(connection.database) }
        }

        package func fetchAll<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> [(repeat (each Value).QueryOutput)]
        where QueryValue == (repeat each Value) {
            try Array(QueryPackCursor<repeat each Value>(db: db, query: query, cached: true))
        }

        package func fetchOne<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> (repeat (each Value).QueryOutput)?
        where QueryValue == (repeat each Value) {
            try QueryPackCursor<repeat each Value>(db: db, query: query, cached: true).next()
        }

        package func fetchCursor<each Value: QueryRepresentable>(
            _ db: GRDB.Database
        ) throws -> QueryCursor<(repeat (each Value).QueryOutput)>
        where QueryValue == (repeat each Value) {
            QueryCursor(try QueryPackCursor<repeat each Value>(db: db, query: query, cached: false))
        }
    }

    extension SelectStatement where QueryValue == (), Joins == () {
        public func fetchCursor(_ connection: SQLite.Connection) throws(ISO_9075.Error) -> QueryCursor<From.QueryOutput> {
            try performing { try fetchCursor(connection.database) }
        }

        package func fetchCount(_ db: GRDB.Database) throws -> Int {
            try asSelect().count().fetchOne(db) ?? 0
        }

        package func fetchAll(_ db: GRDB.Database) throws -> [From.QueryOutput] {
            try Array(QueryValueCursor<From>(db: db, query: query, cached: true))
        }

        package func fetchOne(_ db: GRDB.Database) throws -> From.QueryOutput? {
            try QueryValueCursor<From>(db: db, query: asSelect().limit(1).query, cached: true).next()
        }

        package func fetchCursor(_ db: GRDB.Database) throws -> QueryCursor<From.QueryOutput> {
            QueryCursor(try QueryValueCursor<From>(db: db, query: query, cached: false))
        }
    }

    extension SQLite {
        public struct NotFound: Swift.Error, Hashable, Sendable {
            public init() {}
        }
    }

    extension SelectStatement where QueryValue == (), From: SQL::PrimaryKeyedTable, Joins == () {
        public func find(
            _ connection: SQLite.Connection,
            key primaryKey: some QueryExpression<From.PrimaryKey>
        ) throws -> From.QueryOutput {
            try translatingErrors { try find(connection.database, key: primaryKey) }
        }

        package func find(
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
        public func fetchCursor<each J: SQL::Table>(
            _ connection: SQLite.Connection
        ) throws(ISO_9075.Error) -> QueryCursor<(From.QueryOutput, repeat (each J).QueryOutput)>
        where Joins == (repeat each J) {
            try performing { try fetchCursor(connection.database) }
        }

        package func fetchAll<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> [(From.QueryOutput, repeat (each J).QueryOutput)]
        where Joins == (repeat each J) {
            try Array(QueryPackCursor<From, repeat each J>(db: db, query: query, cached: true))
        }

        package func fetchOne<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> (From.QueryOutput, repeat (each J).QueryOutput)?
        where Joins == (repeat each J) {
            try QueryPackCursor<From, repeat each J>(db: db, query: asSelect().limit(1).query, cached: true).next()
        }

        package func fetchCursor<each J: SQL::Table>(
            _ db: GRDB.Database
        ) throws -> QueryCursor<(From.QueryOutput, repeat (each J).QueryOutput)>
        where Joins == (repeat each J) {
            QueryCursor(try QueryPackCursor<From, repeat each J>(db: db, query: query, cached: false))
        }
    }
#endif
