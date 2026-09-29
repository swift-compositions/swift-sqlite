#if Observation
    public import GRDB
    public import SQL

    @MainActor
    @propertyWrapper
    public struct FetchAll<Element: Sendable> {
        public let projectedValue: FetchStore<ResultsSectionCollection<Element, String?>>

        public var wrappedValue: [Element] { projectedValue.value.elements }

        public var sections: ResultsSectionCollection<Element, String?> { projectedValue.value }

        public init(wrappedValue: [Element] = []) {
            projectedValue = FetchStore(value: ResultsSectionCollection(elements: wrappedValue, sectionName: nil))
        }

        public init<QueryValue: QueryRepresentable>(
            wrappedValue: [Element] = [],
            _ statement: some SQL::Statement<QueryValue>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Element == QueryValue.QueryOutput {
            self.init(wrappedValue: wrappedValue)
            projectedValue.load(statement, database: database, scheduling: scheduler)
        }

        public init(
            wrappedValue: [Element] = [],
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Element: SQL::Table, Element.QueryOutput == Element {
            self.init(wrappedValue: wrappedValue)
            let statement: Select<Element, Element, ()> = Element.all.selectStar()
            projectedValue.load(statement, database: database, scheduling: scheduler)
        }

        public init(
            wrappedValue: [Element] = [],
            @_SectionBuilder<String?> sectionBy sectioning: (Element.TableColumns) -> _Sectioning<String?>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Element: SQL::Table, Element.QueryOutput == Element {
            self.init(wrappedValue: wrappedValue)
            projectedValue.load(
                Element.all.asSelect(),
                sectionBy: sectioning(Element.columns),
                database: database,
                scheduling: scheduler
            )
        }

        public init<S: SelectStatement>(
            wrappedValue: [Element] = [],
            _ statement: S,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where S.QueryValue == (), S.From == Element, S.Joins == (), Element.QueryOutput == Element {
            self.init(wrappedValue: wrappedValue)
            let statement: Select<Element, Element, ()> = statement.selectStar()
            projectedValue.load(statement, database: database, scheduling: scheduler)
        }

        public init<S: SelectStatement>(
            wrappedValue: [Element] = [],
            _ statement: S,
            @_SectionBuilder<String?> sectionBy sectioning: (Element.TableColumns) -> _Sectioning<String?>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where S.QueryValue == (), S.From == Element, S.Joins == (), Element.QueryOutput == Element {
            self.init(wrappedValue: wrappedValue)
            projectedValue.load(
                statement.asSelect(),
                sectionBy: sectioning(Element.columns),
                database: database,
                scheduling: scheduler
            )
        }

        public init<QueryValue: QueryRepresentable, From: SQL::Table>(
            wrappedValue: [Element] = [],
            _ statement: Select<QueryValue, From, ()>,
            @_SectionBuilder<String?> sectionBy sectioning: (From.TableColumns) -> _Sectioning<String?>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Element == QueryValue.QueryOutput {
            self.init(wrappedValue: wrappedValue)
            projectedValue.load(statement, sectionBy: sectioning(From.columns), database: database, scheduling: scheduler)
        }
    }

    extension FetchStore {
        public func load<Element: Sendable, QueryValue: QueryRepresentable>(
            _ statement: some SQL::Statement<QueryValue>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Value == ResultsSectionCollection<Element, String?>, Element == QueryValue.QueryOutput {
            load(Unsectioned<QueryValue>(query: statement.query), database: database, scheduling: scheduler)
        }

        public func load<Element: Sendable>(
            _ statement: Select<(), Element, ()>,
            sectionBy sectioning: _Sectioning<String?>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Value == ResultsSectionCollection<Element, String?>, Element: SQL::Table, Element.QueryOutput == Element {
            let sectioned: Select<(Element, String?), Element, ()> = sectionedColumns(of: Element.self, sectioning) + statement
            load(Sectioned<Element>(query: sectioned.query), database: database, scheduling: scheduler)
        }

        public func load<Element: Sendable, QueryValue: QueryRepresentable, From: SQL::Table>(
            _ statement: Select<QueryValue, From, ()>,
            sectionBy sectioning: _Sectioning<String?>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Value == ResultsSectionCollection<Element, String?>, Element == QueryValue.QueryOutput {
            let ordered: Select<QueryValue, From, ()> = sectionedOrder(of: From.self, sectioning) + statement
            let sectioned: Select<(QueryValue, String?), From, ()> = ordered + sectionedColumn(of: From.self, sectioning)
            load(Sectioned<QueryValue>(query: sectioned.query), database: database, scheduling: scheduler)
        }
    }

    struct Unsectioned<QueryValue: QueryRepresentable>: FetchKeyRequest where QueryValue.QueryOutput: Sendable {
        let query: ISO_9075.Fragment

        func fetch(_ database: GRDB.Database) throws -> ResultsSectionCollection<QueryValue.QueryOutput, String?> {
            ResultsSectionCollection(
                elements: try Array(QueryValueCursor<QueryValue>(db: database, query: query, cached: true)),
                sectionName: nil
            )
        }
    }

    struct Sectioned<QueryValue: QueryRepresentable>: FetchKeyRequest where QueryValue.QueryOutput: Sendable {
        let query: ISO_9075.Fragment

        func fetch(_ database: GRDB.Database) throws -> ResultsSectionCollection<QueryValue.QueryOutput, String?> {
            try ResultsSectionCollection(
                cursor: QuerySectionedCursor<QueryValue, String?>(db: database, query: query, cached: true)
            )
        }
    }
#endif
