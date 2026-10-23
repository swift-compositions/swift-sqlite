#if GRDB
    package import GRDB
    public import SQL

    extension SQL::Table {
        public static func fetchAll(_ connection: SQLite.Connection) throws -> [QueryOutput] {
            try all.fetchAll(connection)
        }

        public static func fetchOne(_ connection: SQLite.Connection) throws -> QueryOutput? {
            try all.fetchOne(connection)
        }

        public static func fetchCount(_ connection: SQLite.Connection) throws -> Int {
            try all.fetchCount(connection)
        }

        public static func fetchCursor(_ connection: SQLite.Connection) throws -> QueryCursor<QueryOutput> {
            try all.fetchCursor(connection)
        }

        package static func fetchAll(_ db: GRDB.Database) throws -> [QueryOutput] {
            try all.fetchAll(db)
        }

        package static func fetchOne(_ db: GRDB.Database) throws -> QueryOutput? {
            try all.fetchOne(db)
        }

        package static func fetchCount(_ db: GRDB.Database) throws -> Int {
            try all.fetchCount(db)
        }

        package static func fetchCursor(_ db: GRDB.Database) throws -> QueryCursor<QueryOutput> {
            try all.fetchCursor(db)
        }
    }

    extension SQL::PrimaryKeyedTable {
        public static func find(
            _ connection: SQLite.Connection,
            key primaryKey: some QueryExpression<PrimaryKey>
        ) throws -> QueryOutput {
            try all.find(connection, key: primaryKey)
        }

        package static func find(
            _ db: GRDB.Database,
            key primaryKey: some QueryExpression<PrimaryKey>
        ) throws -> QueryOutput {
            try all.find(db, key: primaryKey)
        }
    }
#endif
