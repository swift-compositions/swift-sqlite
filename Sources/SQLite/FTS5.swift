public import ISO_9075_Foundation
public import SQL

public protocol FTS5: Table {}

extension TableDefinition where QueryValue: FTS5 {
  public func bm25(
    _ rankings: KeyValuePairs<PartialKeyPath<QueryValue>, Double> = [:]
  ) -> some QueryExpression<Double> {
    var queryFragments: [ISO_9075.Fragment] = ["\(quote: QueryValue.tableName)"]
    if !rankings.isEmpty {
      var columnNameToRanking: ISO_9075.Fragment = """
        CASE "name"
        """
      for (keyPath, ranking) in rankings {
        guard let column = Self.allColumns.first(where: { $0.keyPath == keyPath }) else {
          preconditionFailure("Key path cannot be used in 'bm25': \(keyPath) is not a column of \(QueryValue.self)")
        }
        columnNameToRanking.append(
          """
           WHEN \(bind: column.name) THEN \(ranking)
          """
        )
      }
      columnNameToRanking.append(" ELSE 1 END")
      for offset in Self.writableColumns.indices {
        queryFragments.append(
          """
          (SELECT \(columnNameToRanking) \
          FROM pragma_table_info(\(text: QueryValue.tableName)) \
          WHERE "cid" = \(offset))
          """
        )
      }
    }
    return SQLQueryExpression("bm25(\(queryFragments.joined(separator: ", ")))")
  }

  public func match(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
    SQLQueryExpression(
      """
      (\(QueryValue.self) MATCH \(bind: "\(pattern)"))
      """
    )
  }

  public var rank: some QueryExpression<Double?> {
    SQLQueryExpression(
      """
      \(QueryValue.self)."rank"
      """
    )
  }
}

extension TableColumnExpression
where
  Root: FTS5,
  Value.QueryOutput: _OptionalPromotable,
  Value.QueryOutput._Optionalized.Wrapped: StringProtocol
{
  public func highlight(
    _ open: some StringProtocol,
    _ close: some StringProtocol
  ) -> some QueryExpression<Value> {
    SQLQueryExpression(
      """
      highlight(\
      \(quote: Root.tableName), \
      (\(cid)),
      \(text: "\(open)"), \
      \(text: "\(close)")\
      )
      """
    )
  }

  public func match(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
    Root.columns.match("\(name):\(ISO_9075.Identifier("\(pattern)").delimited)")
  }

  public func snippet(
    _ open: some StringProtocol,
    _ close: some StringProtocol,
    _ ellipsis: some StringProtocol,
    _ tokens: Int
  ) -> some QueryExpression<Value> {
    SQLQueryExpression(
      """
      snippet(\
      \(quote: Root.tableName), \
      (\(cid)),
      \(text: "\(open)"), \
      \(text: "\(close)"), \
      \(text: "\(ellipsis)"), \
      \(raw: tokens)\
      )
      """
    )
  }
}

extension TableColumnExpression {
  fileprivate var cid: some Statement<Int> {
    SQLQueryExpression(
      """
      SELECT "cid" FROM pragma_table_info(\(text: Root.tableName)) \
      WHERE "name" = \(text: name)
      """
    )
  }
}

extension Optional: FTS5 where Wrapped: FTS5 {}

extension TableAlias: FTS5 where Base: FTS5 {}
