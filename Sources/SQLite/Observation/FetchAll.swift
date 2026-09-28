#if Observation
    public import GRDB
    public import SQL

    @MainActor
    @propertyWrapper
    public struct FetchAll<Element: Sendable> {
        public let projectedValue: FetchStore<[Element]>

        public var wrappedValue: [Element] { projectedValue.value }

        public init(wrappedValue: [Element] = []) {
            projectedValue = FetchStore(value: wrappedValue)
        }

        public init<QueryValue: QueryRepresentable>(
            wrappedValue: [Element] = [],
            _ statement: some SQL.Statement<QueryValue>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Element == QueryValue.QueryOutput {
            projectedValue = FetchStore(value: wrappedValue)
            projectedValue.load(statement, database: database, scheduling: scheduler)
        }

        public init(
            wrappedValue: [Element] = [],
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Element: SQL.Table, Element.QueryOutput == Element {
            projectedValue = FetchStore(value: wrappedValue)
            projectedValue.load(StatementValues<Element>(query: Element.all.query), database: database, scheduling: scheduler)
        }
    }

    extension FetchStore {
        public func load<Element, QueryValue: QueryRepresentable>(
            _ statement: some SQL.Statement<QueryValue>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Value == [Element], Element == QueryValue.QueryOutput {
            load(StatementValues<QueryValue>(query: statement.query), database: database, scheduling: scheduler)
        }
    }
#endif
