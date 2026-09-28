public import ISO_9075_Foundation
public import Foundation
public import SQL

extension Table {
  public static func createTemporaryTrigger(
    _ name: String? = nil,
    ifNotExists: Bool = false,
    after operation: TemporaryTrigger<Self>.Operation,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> TemporaryTrigger<Self> {
    TemporaryTrigger(
      name: name,
      ifNotExists: ifNotExists,
      operation: operation,
      when: .after,
      fileID: fileID,
      line: line,
      column: column
    )
  }

  public static func createTemporaryTrigger(
    _ name: String? = nil,
    ifNotExists: Bool = false,
    before operation: TemporaryTrigger<Self>.Operation,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> TemporaryTrigger<Self> {
    TemporaryTrigger(
      name: name,
      ifNotExists: ifNotExists,
      operation: operation,
      when: .before,
      fileID: fileID,
      line: line,
      column: column
    )
  }

  public static func createTemporaryTrigger(
    _ name: String? = nil,
    ifNotExists: Bool = false,
    insteadOf operation: TemporaryTrigger<Self>.Operation,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> TemporaryTrigger<Self> {
    TemporaryTrigger(
      name: name,
      ifNotExists: ifNotExists,
      operation: operation,
      when: .insteadOf,
      fileID: fileID,
      line: line,
      column: column
    )
  }
}

public struct TemporaryTrigger<On: Table>: Sendable, Statement {
  public typealias From = Never
  public typealias Joins = ()
  public typealias QueryValue = ()

  fileprivate enum When: ISO_9075.Fragment {
    case before = "BEFORE"
    case after = "AFTER"
    case insteadOf = "INSTEAD OF"
  }

  public struct Operation: Sendable, QueryExpression {
    public typealias QueryValue = ()

    public enum _Old: AliasName { public static var aliasName: String { "old" } }
    public enum _New: AliasName { public static var aliasName: String { "new" } }

    public typealias Old = TableAlias<On, _Old>.TableColumns
    public typealias New = TableAlias<On, _New>.TableColumns

    public static func insert(
      @QueryFragmentBuilder<any Statement>
      forEachRow perform: (_ new: New) -> [ISO_9075.Fragment],
      when condition: ((_ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      Self(
        kind: .insert(operations: perform(On.as(_New.self).columns)),
        when: condition?(On.as(_New.self).columns)
      )
    }

    @_disfavoredOverload
    public static func insert(
      touch updates: (inout Updates<On>) -> Void,
      when condition: ((_ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      insert(
        forEachRow: { new in
          On
            .where { $0.rowid.eq(new.rowid) }
            .update { updates(&$0) }
        },
        when: condition
      )
    }

    @_disfavoredOverload
    public static func insert<D: _OptionalPromotable<Date?>>(
      touch dateColumn: KeyPath<On.TableColumns, TableColumn<On, D>>,
      when condition: ((_ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      insert(
        touch: dateColumn,
        date: SQLQueryExpression<D>(subsecDateTime()),
        when: condition
      )
    }

    @_disfavoredOverload
    public static func insert<D: _OptionalPromotable<Date?>>(
      touch dateColumn: KeyPath<On.TableColumns, TableColumn<On, D>>,
      date dateFunction: any QueryExpression<D>,
      when condition: ((_ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      insert(
        touch: { $0[dynamicMember: dateColumn] = dateFunction },
        when: condition
      )
    }

    public static func update(
      @QueryFragmentBuilder<any Statement>
      forEachRow perform: (_ old: Old, _ new: New) -> [ISO_9075.Fragment],
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      update(
        of: { _ in },
        forEachRow: perform,
        when: condition
      )
    }

    public static func update<each Column: _TableColumnExpression>(
      of columns: (On.TableColumns) -> (repeat each Column),
      @QueryFragmentBuilder<any Statement>
      forEachRow perform: (_ old: Old, _ new: New) -> [ISO_9075.Fragment],
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      Self(
        kind: .update(
          operations: perform(On.as(_Old.self).columns, On.as(_New.self).columns),
          columnNames: {
            var columnNames: [String] = []
            for column in repeat each columns(On.columns) {
              columnNames.append(contentsOf: column._names)
            }
            return columnNames
          }()
        ),
        when: condition?(On.as(_Old.self).columns, On.as(_New.self).columns)
      )
    }

    @_disfavoredOverload
    public static func update(
      touch updates: (inout Updates<On>) -> Void,
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      update(
        forEachRow: { _, new in
          On
            .where { $0.rowid.eq(new.rowid) }
            .update { updates(&$0) }
        },
        when: condition
      )
    }

    @_disfavoredOverload
    public static func update<D: _OptionalPromotable<Date?>>(
      touch dateColumn: KeyPath<On.TableColumns, TableColumn<On, D>>,
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      update(
        touch: dateColumn,
        date: SQLQueryExpression<D>(subsecDateTime()),
        when: condition
      )
    }

    @_disfavoredOverload
    public static func update<D: _OptionalPromotable<Date?>>(
      touch dateColumn: KeyPath<On.TableColumns, TableColumn<On, D>>,
      date dateFunction: any QueryExpression<D>,
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      update(
        touch: { $0[dynamicMember: dateColumn] = dateFunction },
        when: condition
      )
    }

    @_disfavoredOverload
    public static func update<each Column: _TableColumnExpression>(
      of columns: (On.TableColumns) -> (repeat each Column),
      touch updates: (inout Updates<On>) -> Void,
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      update(
        of: columns,
        forEachRow: { _, new in
          On
            .where { $0.rowid.eq(new.rowid) }
            .update { updates(&$0) }
        },
        when: condition
      )
    }

    @_disfavoredOverload
    public static func update<each Column: _TableColumnExpression, D: _OptionalPromotable<Date?>>(
      of columns: (On.TableColumns) -> (repeat each Column),
      touch dateColumn: KeyPath<On.TableColumns, TableColumn<On, D>>,
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      update(
        of: columns,
        touch: dateColumn,
        date: SQLQueryExpression<D>(subsecDateTime()),
        when: condition
      )
    }

    @_disfavoredOverload
    public static func update<each Column: _TableColumnExpression, D: _OptionalPromotable<Date?>>(
      of columns: (On.TableColumns) -> (repeat each Column),
      touch dateColumn: KeyPath<On.TableColumns, TableColumn<On, D>>,
      date dateFunction: any QueryExpression<D>,
      when condition: ((_ old: Old, _ new: New) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      update(
        of: columns,
        touch: { $0[dynamicMember: dateColumn] = dateFunction },
        when: condition
      )
    }

    public static func delete(
      @QueryFragmentBuilder<any Statement>
      forEachRow perform: (_ old: Old) -> [ISO_9075.Fragment],
      when condition: ((_ old: Old) -> any QueryExpression<Bool>)? = nil
    ) -> Self {
      Self(
        kind: .delete(operations: perform(On.as(_Old.self).columns)),
        when: condition?(On.as(_Old.self).columns)
      )
    }

    private enum Kind {
      case insert(operations: [ISO_9075.Fragment])
      case update(operations: [ISO_9075.Fragment], columnNames: [String])
      case delete(operations: [ISO_9075.Fragment])
    }

    private let kind: Kind
    private let when: ISO_9075.Fragment?

    private init(
      kind: @autoclosure () -> Kind,
      when: @autoclosure () -> (any QueryExpression<Bool>)?
    ) {
      let (kind, when) = $_isCreatingTemporaryTrigger.withValue(true) {
        (kind(), when()?.queryFragment)
      }
      self.kind = kind
      self.when = when
    }

    public var queryFragment: ISO_9075.Fragment {
      var query: ISO_9075.Fragment = ""
      let statements: [ISO_9075.Fragment]
      switch kind {
      case .insert(let begin):
        query.append("INSERT")
        statements = begin
      case .update(let begin, let columnNames):
        query.append("UPDATE")
        if !columnNames.isEmpty {
          query.append(
            " OF \(columnNames.map { ISO_9075.Fragment(quote: $0) }.joined(separator: ", "))"
          )
        }
        statements = begin
      case .delete(let begin):
        query.append("DELETE")
        statements = begin
      }
      query.append(" ON \(On.self)\(.newlineOrSpace)FOR EACH ROW")
      if let when {
        query.append(" WHEN \(when)")
      }
      query.append(" BEGIN")
      for statement in statements {
        query.append("\(.newlineOrSpace)\(statement.indented());")
      }
      query.append("\(.newlineOrSpace)END")
      return query
    }

    fileprivate var description: String {
      switch kind {
      case .insert: "after_insert"
      case .update: "after_update"
      case .delete: "after_delete"
      }
    }
  }

  fileprivate let name: String?
  fileprivate let ifNotExists: Bool
  fileprivate let operation: Operation
  fileprivate let when: When
  fileprivate let fileID: StaticString
  fileprivate let line: UInt
  fileprivate let column: UInt

  public func drop(ifExists: Bool = false) -> some Statement<()> {
    var query: ISO_9075.Fragment = "DROP TRIGGER"
    if ifExists {
      query.append(" IF EXISTS")
    }
    query.append(" \(triggerName)")
    return SQLQueryExpression(query)
  }

  public var query: ISO_9075.Fragment {
    var query: ISO_9075.Fragment = "CREATE TEMPORARY TRIGGER"
    if ifNotExists {
      query.append(" IF NOT EXISTS")
    }
    query.append("\(.newlineOrSpace)\(triggerName.indented())")
    query.append("\(.newlineOrSpace)\(when.rawValue) \(operation)")
    return query.compiled(statementType: "CREATE TEMPORARY TRIGGER")
  }

  private var triggerName: ISO_9075.Fragment {
    "\(quote: name ?? "\(operation.description)_on_\(On.tableName)@\(fileID):\(line):\(column)")"
  }
}

@TaskLocal public var _isCreatingTemporaryTrigger = false
