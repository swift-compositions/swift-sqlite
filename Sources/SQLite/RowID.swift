public import SQL

extension TableDefinition {
  public var rowid: some QueryExpression<Int> {
    SQLQueryExpression(
      """
      \(QueryValue.self)."rowid"
      """
    )
  }
}
