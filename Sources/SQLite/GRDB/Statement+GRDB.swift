public import SQLite_SQL
#if GRDB
    package import GRDB
    public import SQL

    // Every typed operation comes twice: public, on the `SQLite.Connection` a read or write gives, and package-wide, on
    // the driver's connection, which the CloudKit engine and white-box tests run on.

    extension SQL::Statement {
        public func execute(_ connection: SQLite.Connection) throws(SQLite.Error) where QueryValue == () {
            try executing { try execute(connection.database) }
        }

        public func fetchAll(_ connection: SQLite.Connection) throws(SQLite.Error) -> [QueryValue.QueryOutput]
        where QueryValue: QueryRepresentable {
            try executing { try fetchAll(connection.database) }
        }

        public func fetchOne(_ connection: SQLite.Connection) throws(SQLite.Error) -> QueryValue.QueryOutput?
        where QueryValue: QueryRepresentable {
            try executing { try fetchOne(connection.database) }
        }

        public func fetchCursor(_ connection: SQLite.Connection) throws(SQLite.Error) -> QueryCursor<QueryValue.QueryOutput>
        where QueryValue: QueryRepresentable {
            try executing { try fetchCursor(connection.database) }
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
        public func fetchAll<each Value: QueryRepresentable>(
            _ connection: SQLite.Connection
        ) throws(SQLite.Error) -> [(repeat (each Value).QueryOutput)]
        where QueryValue == (repeat each Value) {
            try executing { try fetchAll(connection.database) }
        }

        public func fetchOne<each Value: QueryRepresentable>(
            _ connection: SQLite.Connection
        ) throws(SQLite.Error) -> (repeat (each Value).QueryOutput)?
        where QueryValue == (repeat each Value) {
            try executing { try fetchOne(connection.database) }
        }

        public func fetchCursor<each Value: QueryRepresentable>(
            _ connection: SQLite.Connection
        ) throws(SQLite.Error) -> QueryCursor<(repeat (each Value).QueryOutput)>
        where QueryValue == (repeat each Value) {
            try executing { try fetchCursor(connection.database) }
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
        public func fetchCount(_ connection: SQLite.Connection) throws(SQLite.Error) -> Int {
            try executing { try fetchCount(connection.database) }
        }

        public func fetchAll(_ connection: SQLite.Connection) throws(SQLite.Error) -> [From.QueryOutput] {
            try executing { try fetchAll(connection.database) }
        }

        public func fetchOne(_ connection: SQLite.Connection) throws(SQLite.Error) -> From.QueryOutput? {
            try executing { try fetchOne(connection.database) }
        }

        public func fetchCursor(_ connection: SQLite.Connection) throws(SQLite.Error) -> QueryCursor<From.QueryOutput> {
            try executing { try fetchCursor(connection.database) }
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
        public func fetchAll<each J: SQL::Table>(
            _ connection: SQLite.Connection
        ) throws(SQLite.Error) -> [(From.QueryOutput, repeat (each J).QueryOutput)]
        where Joins == (repeat each J) {
            try executing { try fetchAll(connection.database) }
        }

        public func fetchOne<each J: SQL::Table>(
            _ connection: SQLite.Connection
        ) throws(SQLite.Error) -> (From.QueryOutput, repeat (each J).QueryOutput)?
        where Joins == (repeat each J) {
            try executing { try fetchOne(connection.database) }
        }

        public func fetchCursor<each J: SQL::Table>(
            _ connection: SQLite.Connection
        ) throws(SQLite.Error) -> QueryCursor<(From.QueryOutput, repeat (each J).QueryOutput)>
        where Joins == (repeat each J) {
            try executing { try fetchCursor(connection.database) }
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
