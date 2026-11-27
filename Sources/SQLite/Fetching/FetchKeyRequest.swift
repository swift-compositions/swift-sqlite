public import ISO_9075_Call_Level_Interface
internal import SQL
public import SQLite_SQL

/// What an observed fetch reads: one value, from one connection, in one transaction.
///
/// `fetch` runs again after every committed write, on the writer, and must only read.
public protocol FetchKeyRequest<Value>: Sendable {
    associatedtype Value

    func fetch(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
}

struct StatementValue<QueryValue: QueryRepresentable>: FetchKeyRequest {
    let query: ISO.`9075`.Fragment

    func fetch(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> QueryValue.QueryOutput? {
        try SQLQueryExpression(query, as: QueryValue.self).fetch.one(connection)
    }
}

struct Coalescing<Wrapped: Sendable, Base: FetchKeyRequest<Wrapped?>>: FetchKeyRequest {
    let base: Base
    let value: Wrapped

    func fetch(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Wrapped {
        try base.fetch(connection) ?? value
    }
}

struct Unsectioned<QueryValue: QueryRepresentable>: FetchKeyRequest where QueryValue.QueryOutput: Sendable {
    let query: ISO.`9075`.Fragment

    func fetch(
        _ connection: borrowing SQLite.Connection
    ) throws(ISO.`9075`.Error) -> ResultsSectionCollection<QueryValue.QueryOutput, String?> {
        ResultsSectionCollection(
            elements: try SQLQueryExpression(query, as: QueryValue.self).fetch.all(connection),
            sectionName: nil
        )
    }
}

/// A statement whose last column is the section's name, and whose rows come ordered by it.
struct Sectioned<QueryValue: QueryRepresentable>: FetchKeyRequest where QueryValue.QueryOutput: Sendable {
    let query: ISO.`9075`.Fragment

    func fetch(
        _ connection: borrowing SQLite.Connection
    ) throws(ISO.`9075`.Error) -> ResultsSectionCollection<QueryValue.QueryOutput, String?> {
        ResultsSectionCollection(
            sectioned: try SQLQueryExpression(query, as: (QueryValue, String?).self).fetch.all(connection)
        )
    }
}
