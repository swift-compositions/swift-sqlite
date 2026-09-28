#if GRDB
public import GRDB
import ISO_9075_Foundation
public import SQL

extension SelectStatement where QueryValue == (), Joins == () {
  public func fetchAll<Key: QueryRepresentable>(
    _ db: GRDB.Database,
    @_SectionBuilder<Key> sectionBy sectioning: (From.TableColumns) -> _Sectioning<Key>
  ) throws -> ResultsSectionCollection<From.QueryOutput, Key.QueryOutput>
  where Key.QueryOutput: Hashable {
    let sectionBy = sectioning(From.columns)
    let statement: Select<(), From, ()> = asSelect()
    let prefix: Select<(From, Key), From, ()> = sectionedColumns(of: From.self, sectionBy)
    let sectioned: Select<(From, Key), From, ()> = prefix + statement
    return try sectionedResults(From.self, Key.self, db: db, query: sectioned.query)
  }

  public func fetchAll<Key: QueryRepresentable>(
    _ db: GRDB.Database,
    sectionBy sectionKeyPath: KeyPath<
      From.TableColumns, some QueryExpression<Key>
    >
  ) throws -> ResultsSectionCollection<From.QueryOutput, Key.QueryOutput>
  where Key.QueryOutput: Hashable {
    try fetchAll(db, sectionBy: { $0[keyPath: sectionKeyPath] })
  }
}

extension Select where From: SQL.Table {
  @_documentation(visibility: private)
  @_disfavoredOverload
  public func fetchAll<Key: QueryRepresentable, each J: SQL.Table>(
    _ db: GRDB.Database,
    @_SectionBuilder<Key> sectionBy sectioning: (
      From.TableColumns, repeat (each J).TableColumns
    ) -> _Sectioning<Key>
  ) throws -> ResultsSectionCollection<QueryValue.QueryOutput, Key.QueryOutput>
  where QueryValue: QueryRepresentable, Joins == (repeat each J), Key.QueryOutput: Hashable {
    let sectionBy = sectioning(From.columns, repeat (each J).columns)
    return try sectionedResults(db, statement: self, sectionBy: sectionBy)
  }

  @_documentation(visibility: private)
  public func fetchAll<Key: QueryRepresentable>(
    _ db: GRDB.Database,
    @_SectionBuilder<Key> sectionBy sectioning: (
      From.TableColumns, Joins.TableColumns
    ) -> _Sectioning<Key>
  ) throws -> ResultsSectionCollection<QueryValue.QueryOutput, Key.QueryOutput>
  where
    QueryValue: QueryRepresentable,
    Joins: SQL.Table,
    Key.QueryOutput: Hashable
  {
    let sectionBy = sectioning(From.columns, Joins.columns)
    return try sectionedResults(db, statement: self, sectionBy: sectionBy)
  }

  public func fetchAll<Key: QueryRepresentable>(
    _ db: GRDB.Database,
    sectionBy sectionKeyPath: KeyPath<
      From.TableColumns, some QueryExpression<Key>
    >
  ) throws -> ResultsSectionCollection<QueryValue.QueryOutput, Key.QueryOutput>
  where QueryValue: QueryRepresentable, Joins == (), Key.QueryOutput: Hashable {
    try fetchAll(db, sectionBy: { $0[keyPath: sectionKeyPath] })
  }
}

private func sectionedResults<
  Value: QueryRepresentable,
  From: SQL.Table,
  each J: SQL.Table,
  Key: QueryRepresentable
>(
  _ db: GRDB.Database,
  statement: Select<Value, From, (repeat each J)>,
  sectionBy: _Sectioning<Key>
) throws -> ResultsSectionCollection<Value.QueryOutput, Key.QueryOutput>
where Key.QueryOutput: Hashable {
  let ordered: Select<Value, From, (repeat each J)> =
    sectionedOrder(of: From.self, sectionBy) + statement
  let sectioned: Select<(Value, Key), From, (repeat each J)> =
    ordered + sectionedColumn(of: From.self, sectionBy)
  return try sectionedResults(Value.self, Key.self, db: db, query: sectioned.query)
}

private func sectionedResults<Value: QueryRepresentable, Key: QueryRepresentable>(
  _: Value.Type,
  _: Key.Type,
  db: GRDB.Database,
  query: ISO_9075.Fragment
) throws -> ResultsSectionCollection<Value.QueryOutput, Key.QueryOutput>
where Key.QueryOutput: Hashable {
  try ResultsSectionCollection(
    cursor: QuerySectionedCursor<Value, Key>(db: db, query: query, cached: true)
  )
}

#endif
