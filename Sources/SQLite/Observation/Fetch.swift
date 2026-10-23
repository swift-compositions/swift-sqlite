#if Observation

    @MainActor
    @propertyWrapper
    public struct Fetch<Value: Sendable> {
        public let projectedValue: FetchStore<Value>

        public var wrappedValue: Value { projectedValue.value }

        public init(wrappedValue: Value) {
            projectedValue = FetchStore(value: wrappedValue)
        }

        public init(
            wrappedValue: Value,
            _ request: some FetchKeyRequest<Value>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) {
            projectedValue = FetchStore(value: wrappedValue, request, database: database, scheduling: scheduler)
        }
    }
#endif
