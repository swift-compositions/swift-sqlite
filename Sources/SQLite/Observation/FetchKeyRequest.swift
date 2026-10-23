#if Observation
    internal import ISO_9075_Foundation
    internal import SQL
    internal import GRDB

    public protocol FetchKeyRequest<Value>: Sendable {
        associatedtype Value

        func fetch(_ connection: SQLite.Connection) throws -> Value
    }

    struct StatementValue<QueryValue: QueryRepresentable>: FetchKeyRequest {
        let query: ISO_9075.Fragment

        func fetch(_ connection: SQLite.Connection) throws -> QueryValue.QueryOutput? {
            try QueryValueCursor<QueryValue>(db: connection.database, query: query, cached: true).next()
        }
    }

    struct Coalescing<Wrapped: Sendable, Base: FetchKeyRequest<Wrapped?>>: FetchKeyRequest {
        let base: Base
        let value: Wrapped

        func fetch(_ connection: SQLite.Connection) throws -> Wrapped {
            try base.fetch(connection) ?? value
        }
    }
#endif
