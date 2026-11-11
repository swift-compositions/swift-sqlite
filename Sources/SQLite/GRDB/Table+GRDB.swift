public import SQLite_SQL
#if GRDB
    package import GRDB
    public import ISO_9075_Call_Level_Interface
    public import SQL

    extension SQL::Table {
        public static func fetchCursor(_ connection: SQLite.Connection) throws(ISO_9075.Error) -> QueryCursor<QueryOutput> {
            try all.fetchCursor(connection)
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
