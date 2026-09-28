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
            _ statement: some SQL.Statement<QueryValue>,
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
        ) where Element: SQL.Table, Element.QueryOutput == Element {
            self.init(wrappedValue: wrappedValue)
            projectedValue.load(Element.all.asSelect(), database: database, scheduling: scheduler)
        }

        public init(
            wrappedValue: [Element] = [],
            @_SectionBuilder<String?> sectionBy sectioning: (Element.TableColumns) -> _Sectioning<String?>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) where Element: SQL.Table, Element.QueryOutput == Element {
            self.init(wrappedValue: wrappedValue)
            projectedValue.load(
                Element.all.asSelect(),
                sectionBy: sectioning(Element.columns),
                database: database,
                scheduling: scheduler
            )
        }

        public init<QueryValue: QueryRepresentable, From: SQL.Table>(
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
            _ statement: some SQL.Statement<QueryValue>,
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
        ) where Value == ResultsSectionCollection<Element, String?>, Element: SQL.Table, Element.QueryOutput == Element {
            let sectioned: Select<(Element, String?), Element, ()> = sectionedColumns(of: Element.self, sectioning) + statement
            load(Sectioned<Element>(query: sectioned.query), database: database, scheduling: scheduler)
        }

        public func load<Element: Sendable, QueryValue: QueryRepresentable, From: SQL.Table>(
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

    public struct _Sectioning<Key>: Sendable {
        let select: ISO_9075.Fragment
        let order: ISO_9075.Fragment

        package init(_ expression: some QueryExpression) {
            select = expression.queryFragment
            order = expression.queryFragment
        }

        package init<Value>(_ orderingTerm: _OrderingTerm<Value>) {
            select = orderingTerm.baseQueryFragment
            order = orderingTerm.queryFragment
        }
    }

    @resultBuilder
    public enum _SectionBuilder<Key> {
        public static func buildExpression(_ expression: some QueryExpression<Key>) -> _Sectioning<Key> {
            _Sectioning(expression)
        }

        public static func buildExpression(_ orderingTerm: _OrderingTerm<Key>) -> _Sectioning<Key> {
            _Sectioning(orderingTerm)
        }

        public static func buildBlock(_ component: _Sectioning<Key>) -> _Sectioning<Key> {
            component
        }

        public static func buildEither(first component: _Sectioning<Key>) -> _Sectioning<Key> {
            component
        }

        public static func buildEither(second component: _Sectioning<Key>) -> _Sectioning<Key> {
            component
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

    func sectionedColumns<From: SQL.Table>(
        of _: From.Type,
        _ sectioning: _Sectioning<String?>
    ) -> Select<(From, String?), From, ()> {
        From.unscoped
            .select { ($0, SQLQueryExpression(sectioning.select, as: String?.self)) }
            .order { _ in SQLQueryExpression(sectioning.order) }
    }

    func sectionedColumn<From: SQL.Table>(
        of _: From.Type,
        _ sectioning: _Sectioning<String?>
    ) -> Select<String?, From, ()> {
        From.unscoped.asSelect().select { _ in SQLQueryExpression(sectioning.select, as: String?.self) }
    }

    func sectionedOrder<From: SQL.Table>(of _: From.Type, _ sectioning: _Sectioning<String?>) -> Select<(), From, ()> {
        From.unscoped.asSelect().order { _ in SQLQueryExpression(sectioning.order) }
    }
#endif
