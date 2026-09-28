#if Observation
    public import GRDB
    internal import ISO_9075_Foundation
    internal import SQL

    public protocol FetchKeyRequest<Value>: Sendable {
        associatedtype Value

        func fetch(_ database: GRDB.Database) throws -> Value
    }


    struct StatementValue<QueryValue: QueryRepresentable>: FetchKeyRequest {
        let query: ISO_9075.Fragment

        func fetch(_ database: GRDB.Database) throws -> QueryValue.QueryOutput? {
            try QueryValueCursor<QueryValue>(db: database, query: query, cached: true).next()
        }
    }

    struct Coalescing<Wrapped: Sendable, Base: FetchKeyRequest<Wrapped?>>: FetchKeyRequest {
        let base: Base
        let value: Wrapped

        func fetch(_ database: GRDB.Database) throws -> Wrapped {
            try base.fetch(database) ?? value
        }
    }
#endif
