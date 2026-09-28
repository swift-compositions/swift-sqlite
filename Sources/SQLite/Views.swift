public import ISO_9075_Foundation
public import SQL

extension Table {
  public static func createTemporaryView<Selection: PartialSelectStatement>(
    ifNotExists: Bool = false,
    as select: Selection
  ) -> TemporaryView<Self, Selection>
  where Selection.QueryValue == Columns.QueryValue {
    TemporaryView(ifNotExists: ifNotExists, select: select)
  }
}

public struct TemporaryView<View: Table, Selection: PartialSelectStatement>: Statement
where Selection.QueryValue == View {
  public typealias QueryValue = ()
  public typealias From = Never

  fileprivate let ifNotExists: Bool
  fileprivate let select: Selection

  public func drop(ifExists: Bool = false) -> some Statement<()> {
    var query: ISO_9075.Fragment = "DROP VIEW"
    if ifExists {
      query.append(" IF EXISTS")
    }
    query.append(" ")
    if let schemaName = View.schemaName {
      query.append("\(quote: schemaName).")
    }
    query.append(View.tableFragment)
    return SQLQueryExpression(query)
  }

  public var query: ISO_9075.Fragment {
    var query: ISO_9075.Fragment = "CREATE TEMPORARY VIEW"
    if ifNotExists {
      query.append(" IF NOT EXISTS")
    }
    query.append(.newlineOrSpace)
    if let schemaName = View.schemaName {
      query.append("\(quote: schemaName).")
    }
    query.append(View.tableFragment)
    let columnNames: [ISO_9075.Fragment] = View.TableColumns.allColumns
      .map { "\(quote: $0.name)" }
    query.append("\(.newlineOrSpace)(\(columnNames.joined(separator: ", ")))")
    query.append("\(.newlineOrSpace)AS")
    query.append("\(.newlineOrSpace)\(select)")
    return query.compiled(statementType: "CREATE TEMPORARY VIEW")
  }
}
