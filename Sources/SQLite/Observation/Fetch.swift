#if Observation
    public import GRDB

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
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) {
            projectedValue = FetchStore(value: wrappedValue, request, database: database, scheduling: scheduler)
        }
    }
#endif
