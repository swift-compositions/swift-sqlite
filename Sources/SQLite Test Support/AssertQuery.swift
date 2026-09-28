#if GRDB
import CustomDump
public import GRDB
import InlineSnapshotTesting
public import SQL
import SQLite
import SQL_Test_Support

@_disfavoredOverload
public func assertQuery<each V: QueryRepresentable, S: SQL.Statement<(repeat each V)>>(
  includeSQL: Bool = false,
  _ query: S,
  database: some DatabaseReader,
  sql: (() -> String)? = nil,
  results: (() -> String)? = nil,
  fileID: StaticString = #fileID,
  filePath: StaticString = #filePath,
  function: StaticString = #function,
  line: UInt = #line,
  column: UInt = #column
) {
  assertStatement(
    includeSQL: includeSQL,
    query,
    execute: { query in try database.read { try query.fetchAll($0) } },
    sql: sql,
    results: results,
    fileID: fileID,
    filePath: filePath,
    function: function,
    line: line,
    column: column
  )
}

public func assertQuery<S: SelectStatement, each J: SQL.Table>(
  includeSQL: Bool = false,
  _ query: S,
  database: some DatabaseReader,
  sql: (() -> String)? = nil,
  results: (() -> String)? = nil,
  fileID: StaticString = #fileID,
  filePath: StaticString = #filePath,
  function: StaticString = #function,
  line: UInt = #line,
  column: UInt = #column
) where S.QueryValue == (), S.Joins == (repeat each J) {
  assertQuery(
    includeSQL: includeSQL,
    query.selectStar(),
    database: database,
    sql: sql,
    results: results,
    fileID: fileID,
    filePath: filePath,
    function: function,
    line: line,
    column: column
  )
}

public func assertQuery<each V: QueryRepresentable, S: SQL.Statement<(repeat each V)>>(
  includeSQL: Bool = false,
  _ statement: S,
  writing database: some DatabaseWriter,
  sql: (() -> String)? = nil,
  results: (() -> String)? = nil,
  fileID: StaticString = #fileID,
  filePath: StaticString = #filePath,
  function: StaticString = #function,
  line: UInt = #line,
  column: UInt = #column
) {
  assertStatement(
    includeSQL: includeSQL,
    statement,
    execute: { statement in try database.write { try statement.fetchAll($0) } },
    sql: sql,
    results: results,
    fileID: fileID,
    filePath: filePath,
    function: function,
    line: line,
    column: column
  )
}

private func assertStatement<each V: QueryRepresentable, S: SQL.Statement<(repeat each V)>>(
  includeSQL: Bool,
  _ statement: S,
  execute: (S) throws -> [(repeat (each V).QueryOutput)],
  sql: (() -> String)?,
  results: (() -> String)?,
  fileID: StaticString,
  filePath: StaticString,
  function: StaticString,
  line: UInt,
  column: UInt
) {
  guard !includeSQL
  else {
    return SQL_Test_Support.assertQuery(
      statement,
      execute: execute,
      sql: sql,
      results: results,
      snapshotTrailingClosureOffset: 0,
      fileID: fileID,
      filePath: filePath,
      function: function,
      line: line,
      column: column
    )
  }
  assertInlineSnapshot(
    of: switch Result(catching: { try execute(statement) }) {
    case .success(let rows): rows.isEmpty ? "(No results)" : table(rows)
    case .failure(let error): String(describing: error)
    },
    as: .lines,
    message: "Results did not match",
    syntaxDescriptor: InlineSnapshotSyntaxDescriptor(
      trailingClosureLabel: "results",
      trailingClosureOffset: 0
    ),
    matches: sql ?? results,
    fileID: fileID,
    file: filePath,
    function: function,
    line: line,
    column: column
  )
}

private func table<Row>(_ rows: [Row]) -> String {
  let cellRows = rows.map { row in
    Mirror(reflecting: row).displayStyle == .tuple
      ? Mirror(reflecting: row).children.map { dumped($0.value) }
      : [dumped(row)]
  }
  let columnSpans = cellRows.reduce(
    into: [Int](repeating: 0, count: cellRows.map(\.count).max() ?? 0)
  ) { spans, row in
    for (index, cell) in row.enumerated() {
      spans[index] = max(spans[index], cell.split(separator: "\n").map(\.count).max() ?? 0)
    }
  }
  let isMultiline = cellRows.contains { row in row.contains { $0.split(separator: "\n").count > 1 } }
  let border = { (left: String, middle: String, right: String) in
    left + columnSpans.map { String(repeating: "─", count: $0) }.joined(separator: middle) + right
  }
  let renderedRows = cellRows.map { row in
    let columns = row.map { $0.split(separator: "\n") }
    return (0..<(columns.map(\.count).max() ?? 0)).map { offset in
      "│ "
        + zip(columns, columnSpans).map { lines, span in
          let text = offset < lines.count ? String(lines[offset]) : ""
          return text + String(repeating: " ", count: span - text.count)
        }
        .joined(separator: " │ ")
        + " │"
    }
    .joined(separator: "\n")
  }
  return ([border("┌─", "─┬─", "─┐")]
    + [renderedRows.joined(separator: isMultiline ? "\n" + border("├─", "─┼─", "─┤") + "\n" : "\n")]
    + [border("└─", "─┴─", "─┘")])
    .joined(separator: "\n")
}

private func dumped(_ value: Any) -> String {
  var output = ""
  customDump(value, to: &output)
  return output
}
#endif
