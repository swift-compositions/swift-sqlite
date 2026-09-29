#if GRDB
    public import GRDB
    public import SQL

    extension SelectStatement where QueryValue == (), Joins == () {
        public func fetchAll<Key: QueryRepresentable>(
            _ db: GRDB.Database,
            @SectionBuilder<Key> sectionBy sectioning: (From.TableColumns) -> Sectioning<Key>
        ) throws -> ResultsSectionCollection<From.QueryOutput, Key.QueryOutput>
        where Key.QueryOutput: Hashable {
            let sectioned: Select<(From, Key), From, ()> =
                sectionedColumns(of: From.self, sectioning(From.columns)) + asSelect()
            return try ResultsSectionCollection(
                cursor: QuerySectionedCursor<From, Key>(db: db, query: sectioned.query, cached: true)
            )
        }

        public func fetchAll<Key: QueryRepresentable>(
            _ db: GRDB.Database,
            sectionBy sectionKeyPath: KeyPath<From.TableColumns, some QueryExpression<Key>>
        ) throws -> ResultsSectionCollection<From.QueryOutput, Key.QueryOutput>
        where Key.QueryOutput: Hashable {
            try fetchAll(db, sectionBy: { $0[keyPath: sectionKeyPath] })
        }
    }

    extension Select where From: SQL::Table {
        @_disfavoredOverload
        public func fetchAll<Key: QueryRepresentable, each J: SQL::Table>(
            _ db: GRDB.Database,
            @SectionBuilder<Key> sectionBy sectioning: (From.TableColumns, repeat (each J).TableColumns) -> Sectioning<Key>
        ) throws -> ResultsSectionCollection<QueryValue.QueryOutput, Key.QueryOutput>
        where QueryValue: QueryRepresentable, Joins == (repeat each J), Key.QueryOutput: Hashable {
            try sectionedResults(db, statement: self, sectionBy: sectioning(From.columns, repeat (each J).columns))
        }

        public func fetchAll<Key: QueryRepresentable>(
            _ db: GRDB.Database,
            @SectionBuilder<Key> sectionBy sectioning: (From.TableColumns, Joins.TableColumns) -> Sectioning<Key>
        ) throws -> ResultsSectionCollection<QueryValue.QueryOutput, Key.QueryOutput>
        where QueryValue: QueryRepresentable, Joins: SQL::Table, Key.QueryOutput: Hashable {
            try sectionedResults(db, statement: self, sectionBy: sectioning(From.columns, Joins.columns))
        }

        public func fetchAll<Key: QueryRepresentable>(
            _ db: GRDB.Database,
            sectionBy sectionKeyPath: KeyPath<From.TableColumns, some QueryExpression<Key>>
        ) throws -> ResultsSectionCollection<QueryValue.QueryOutput, Key.QueryOutput>
        where QueryValue: QueryRepresentable, Joins == (), Key.QueryOutput: Hashable {
            try fetchAll(db, sectionBy: { $0[keyPath: sectionKeyPath] })
        }
    }

    private func sectionedResults<Value: QueryRepresentable, From: SQL::Table, each J: SQL::Table, Key: QueryRepresentable>(
        _ db: GRDB.Database,
        statement: Select<Value, From, (repeat each J)>,
        sectionBy sectioning: Sectioning<Key>
    ) throws -> ResultsSectionCollection<Value.QueryOutput, Key.QueryOutput>
    where Key.QueryOutput: Hashable {
        let ordered: Select<Value, From, (repeat each J)> = sectionedOrder(of: From.self, sectioning) + statement
        let sectioned: Select<(Value, Key), From, (repeat each J)> = ordered + sectionedColumn(of: From.self, sectioning)
        return try ResultsSectionCollection(
            cursor: QuerySectionedCursor<Value, Key>(db: db, query: sectioned.query, cached: true)
        )
    }

    public struct Sectioning<Key>: Sendable {
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
    public enum SectionBuilder<Key> {
        public static func buildExpression(_ expression: some QueryExpression<Key>) -> Sectioning<Key> {
            Sectioning(expression)
        }

        public static func buildExpression(_ orderingTerm: _OrderingTerm<Key>) -> Sectioning<Key> {
            Sectioning(orderingTerm)
        }

        public static func buildBlock(_ component: Sectioning<Key>) -> Sectioning<Key> {
            component
        }

        public static func buildEither(first component: Sectioning<Key>) -> Sectioning<Key> {
            component
        }

        public static func buildEither(second component: Sectioning<Key>) -> Sectioning<Key> {
            component
        }
    }

    func sectionedColumns<From: SQL::Table, Key: QueryRepresentable>(
        of _: From.Type,
        _ sectioning: Sectioning<Key>
    ) -> Select<(From, Key), From, ()> {
        From.unscoped
            .select { ($0, SQLQueryExpression(sectioning.select, as: Key.self)) }
            .order { _ in SQLQueryExpression(sectioning.order) }
    }

    func sectionedColumn<From: SQL::Table, Key: QueryRepresentable>(
        of _: From.Type,
        _ sectioning: Sectioning<Key>
    ) -> Select<Key, From, ()> {
        From.unscoped.asSelect().select { _ in SQLQueryExpression(sectioning.select, as: Key.self) }
    }

    func sectionedOrder<From: SQL::Table, Key>(of _: From.Type, _ sectioning: Sectioning<Key>) -> Select<(), From, ()> {
        From.unscoped.asSelect().order { _ in SQLQueryExpression(sectioning.order) }
    }
#endif
