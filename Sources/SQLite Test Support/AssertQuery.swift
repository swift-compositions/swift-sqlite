#if GRDB
public import GRDB
public import SQL
import SQLite
import SQL_Test_Support

@_disfavoredOverload
public func assertQuery<each V: QueryRepresentable, S: SQL.Statement<(repeat each V)>>(
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
  SQL_Test_Support.assertQuery(
    query,
    execute: { query in try database.read { try query.fetchAll($0) } },
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

public func assertQuery<S: SelectStatement, each J: SQL.Table>(
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
#endif
