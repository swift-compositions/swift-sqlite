public import SQL
public import SQLite_SQL

extension SQLite {
    /// No row has the primary key that `find` was given.
    public struct NotFound: Swift.Error, Hashable, Sendable {
        public init() {}
    }
}

extension SelectStatement where QueryValue == (), From: SQL::PrimaryKeyedTable, Joins == () {
    /// The row with `primaryKey`; throws ``SQLite/NotFound`` when there is none.
    public func find(
        _ connection: borrowing SQLite.Connection,
        key primaryKey: some QueryExpression<From.PrimaryKey>
    ) throws -> From.QueryOutput {
        guard let record = try asSelect().find(primaryKey).fetch.one(connection) else {
            throw SQLite.NotFound()
        }
        return record
    }
}

extension SQL::PrimaryKeyedTable {
    /// The row with `primaryKey`; throws ``SQLite/NotFound`` when there is none.
    public static func find(
        _ connection: borrowing SQLite.Connection,
        key primaryKey: some QueryExpression<PrimaryKey>
    ) throws -> QueryOutput {
        try all.find(connection, key: primaryKey)
    }
}
