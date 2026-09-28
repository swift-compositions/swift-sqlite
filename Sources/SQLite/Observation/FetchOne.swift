#if Observation
    public import GRDB
    public import SQL

    @MainActor
    @propertyWrapper
    public struct FetchOne<Value: Sendable> {
        public let projectedValue: FetchStore<Value>

        public var wrappedValue: Value { projectedValue.value }

        public init(wrappedValue: Value) {
            projectedValue = FetchStore(value: wrappedValue)
        }

        public init<QueryValue: QueryRepresentable>(
            wrappedValue: Value,
            _ statement: some SQL.Statement<QueryValue>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Value == QueryValue.QueryOutput {
            projectedValue = FetchStore(value: wrappedValue)
            projectedValue.load(
                Coalescing(base: StatementValue<QueryValue>(query: statement.query), value: wrappedValue),
                database: database,
                scheduling: scheduler
            )
        }

        public init<Wrapped, QueryValue: QueryRepresentable>(
            wrappedValue: Wrapped? = nil,
            _ statement: some SQL.Statement<QueryValue>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Value == Wrapped?, Wrapped == QueryValue.QueryOutput {
            projectedValue = FetchStore(value: wrappedValue)
            projectedValue.load(StatementValue<QueryValue>(query: statement.query), database: database, scheduling: scheduler)
        }
    }
#endif
