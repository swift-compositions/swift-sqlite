#if Observation
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
            _ statement: some SQL::Statement<QueryValue>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) where Value == QueryValue.QueryOutput {
            projectedValue = FetchStore(value: wrappedValue)
            projectedValue.start(
                Coalescing(base: StatementValue<QueryValue>(query: statement.query), value: wrappedValue),
                database: database,
                scheduling: scheduler
            )
        }

        public init<Wrapped, QueryValue: QueryRepresentable>(
            wrappedValue: Wrapped? = nil,
            _ statement: some SQL::Statement<QueryValue>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) where Value == Wrapped?, Wrapped == QueryValue.QueryOutput {
            projectedValue = FetchStore(value: wrappedValue)
            projectedValue.start(StatementValue<QueryValue>(query: statement.query), database: database, scheduling: scheduler)
        }
    }
#endif
