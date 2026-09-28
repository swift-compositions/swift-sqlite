public import ISO_9075_Foundation
import Foundation
public import SQL

extension QueryExpression where QueryValue: _AnyJSONRepresentable & _JSONArrayRepresentation {
  public func jsonEach<Element: Table & Codable>()
    -> SelectOf<JSONEach<Int, JSONRepresentation<Element>>>
  where QueryValue._ElementRepresentation: _JSONObjectRepresentation<Element> {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }

  public func jsonEach() -> SelectOf<JSONEach<Int, QueryValue._Element>>
  where QueryValue._Element: QueryRepresentable & QueryBindable {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }
}

extension QueryExpression
where QueryValue: _AnyJSONRepresentable & _JSONDictionaryRepresentation {
  public func jsonEach<Element: Table & Codable>()
    -> SelectOf<JSONEach<QueryValue._Key, JSONRepresentation<Element>>>
  where
    QueryValue._Key: QueryBindable,
    QueryValue._ValueRepresentation: _JSONObjectRepresentation<Element>
  {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }

  public func jsonEach() -> SelectOf<JSONEach<QueryValue._Key, QueryValue._Value>>
  where QueryValue._Key: QueryBindable, QueryValue._Value: QueryRepresentable & QueryBindable {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }
}

extension QueryExpression
where
  QueryValue: StructuredQueriesCore._OptionalProtocol,
  QueryValue.Wrapped: _JSONArrayRepresentation
{
  public func jsonEach<Element: Table & Codable>()
    -> SelectOf<JSONEach<Int, JSONRepresentation<Element>>>
  where QueryValue.Wrapped._ElementRepresentation: _JSONObjectRepresentation<Element> {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }

  public func jsonEach() -> SelectOf<JSONEach<Int, QueryValue.Wrapped._Element>>
  where QueryValue.Wrapped._Element: QueryRepresentable & QueryBindable {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }
}

extension QueryExpression
where
  QueryValue: StructuredQueriesCore._OptionalProtocol,
  QueryValue.Wrapped: _JSONDictionaryRepresentation
{
  public func jsonEach<Element: Table & Codable>()
    -> SelectOf<JSONEach<QueryValue.Wrapped._Key, JSONRepresentation<Element>>>
  where
    QueryValue.Wrapped._Key: QueryBindable,
    QueryValue.Wrapped._ValueRepresentation: _JSONObjectRepresentation<Element>
  {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }

  public func jsonEach()
    -> SelectOf<JSONEach<QueryValue.Wrapped._Key, QueryValue.Wrapped._Value>>
  where
    QueryValue.Wrapped._Key: QueryBindable,
    QueryValue.Wrapped._Value: QueryRepresentable & QueryBindable
  {
    JSONEach.select(from: "json_each(\(argumentFragment))")
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonEach<Context, Member: _JSONArrayRepresentation, Element: Table & Codable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONEach<Int, JSONRepresentation<Element>>>
  where Member._ElementRepresentation: _JSONObjectRepresentation<Element> {
    JSONEach.select(from: jsonEachFragment(path))
  }

  public func jsonEach<Context, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONEach<Int, Member._Element>>
  where Member._Element: QueryRepresentable & QueryBindable {
    JSONEach.select(from: jsonEachFragment(path))
  }

  public func jsonEach<Context, Member: _JSONDictionaryRepresentation, Element: Table & Codable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONEach<Member._Key, JSONRepresentation<Element>>>
  where
    Member._Key: QueryBindable,
    Member._ValueRepresentation: _JSONObjectRepresentation<Element>
  {
    JSONEach.select(from: jsonEachFragment(path))
  }

  public func jsonEach<Context, Member: _JSONDictionaryRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONEach<Member._Key, Member._Value>>
  where Member._Key: QueryBindable, Member._Value: QueryRepresentable & QueryBindable {
    JSONEach.select(from: jsonEachFragment(path))
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable & _JSONArrayRepresentation {
  public func jsonbEach<Element: Table & Codable>()
    -> SelectOf<JSONBEach<Int, JSONBRepresentation<Element>>>
  where QueryValue._ElementRepresentation: _JSONObjectRepresentation<Element> {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }

  public func jsonbEach() -> SelectOf<JSONBEach<Int, QueryValue._Element>>
  where QueryValue._Element: QueryRepresentable & QueryBindable {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }
}

extension QueryExpression
where QueryValue: _AnyJSONRepresentable & _JSONDictionaryRepresentation {
  public func jsonbEach<Element: Table & Codable>()
    -> SelectOf<JSONBEach<QueryValue._Key, JSONBRepresentation<Element>>>
  where
    QueryValue._Key: QueryBindable,
    QueryValue._ValueRepresentation: _JSONObjectRepresentation<Element>
  {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }

  public func jsonbEach() -> SelectOf<JSONBEach<QueryValue._Key, QueryValue._Value>>
  where QueryValue._Key: QueryBindable, QueryValue._Value: QueryRepresentable & QueryBindable {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }
}

extension QueryExpression
where
  QueryValue: StructuredQueriesCore._OptionalProtocol,
  QueryValue.Wrapped: _JSONArrayRepresentation
{
  public func jsonbEach<Element: Table & Codable>()
    -> SelectOf<JSONBEach<Int, JSONBRepresentation<Element>>>
  where QueryValue.Wrapped._ElementRepresentation: _JSONObjectRepresentation<Element> {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }

  public func jsonbEach() -> SelectOf<JSONBEach<Int, QueryValue.Wrapped._Element>>
  where QueryValue.Wrapped._Element: QueryRepresentable & QueryBindable {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }
}

extension QueryExpression
where
  QueryValue: StructuredQueriesCore._OptionalProtocol,
  QueryValue.Wrapped: _JSONDictionaryRepresentation
{
  public func jsonbEach<Element: Table & Codable>()
    -> SelectOf<JSONBEach<QueryValue.Wrapped._Key, JSONBRepresentation<Element>>>
  where
    QueryValue.Wrapped._Key: QueryBindable,
    QueryValue.Wrapped._ValueRepresentation: _JSONObjectRepresentation<Element>
  {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }

  public func jsonbEach()
    -> SelectOf<JSONBEach<QueryValue.Wrapped._Key, QueryValue.Wrapped._Value>>
  where
    QueryValue.Wrapped._Key: QueryBindable,
    QueryValue.Wrapped._Value: QueryRepresentable & QueryBindable
  {
    JSONBEach.select(from: "jsonb_each(\(argumentFragment))")
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonbEach<Context, Member: _JSONArrayRepresentation, Element: Table & Codable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONBEach<Int, JSONBRepresentation<Element>>>
  where Member._ElementRepresentation: _JSONObjectRepresentation<Element> {
    JSONBEach.select(from: jsonbEachFragment(path))
  }

  public func jsonbEach<Context, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONBEach<Int, Member._Element>>
  where Member._Element: QueryRepresentable & QueryBindable {
    JSONBEach.select(from: jsonbEachFragment(path))
  }

  public func jsonbEach<Context, Member: _JSONDictionaryRepresentation, Element: Table & Codable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONBEach<Member._Key, JSONBRepresentation<Element>>>
  where
    Member._Key: QueryBindable,
    Member._ValueRepresentation: _JSONObjectRepresentation<Element>
  {
    JSONBEach.select(from: jsonbEachFragment(path))
  }

  public func jsonbEach<Context, Member: _JSONDictionaryRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> SelectOf<JSONBEach<Member._Key, Member._Value>>
  where Member._Key: QueryBindable, Member._Value: QueryRepresentable & QueryBindable {
    JSONBEach.select(from: jsonbEachFragment(path))
  }
}

public struct JSONEach<
  Key: QueryRepresentable & QueryBindable,
  Value: QueryRepresentable & QueryBindable
>: Table {
  public static var tableName: String { "json_each" }

  public static var columns: TableColumns { TableColumns() }

  public static var _columnWidth: Int { 2 }

  public let key: Key.QueryOutput

  public let value: Value.QueryOutput

  fileprivate static func select(from tableReference: ISO_9075.Fragment) -> SelectOf<JSONEach> {
    var select = all.asSelect()
    select._tableReference = tableReference
    return select
  }

  public struct TableColumns: TableDefinition, Sendable {
    public typealias QueryValue = JSONEach

    public static var allColumns: [any TableColumnExpression] {
      [TableColumns().key, TableColumns().value]
    }

    public static var writableColumns: [any WritableTableColumnExpression] { [] }

    public var key: GeneratedColumn<JSONEach, Key> {
      GeneratedColumn("key", keyPath: \JSONEach.key)
    }

    public var value: GeneratedColumn<JSONEach, Value> {
      GeneratedColumn("value", keyPath: \JSONEach.value)
    }
  }

  public struct Selection: TableExpression {
    public typealias QueryValue = JSONEach

    public var allColumns: [any QueryExpression]

    public init(allColumns: [any QueryExpression]) {
      self.allColumns = allColumns
    }
  }
}

extension JSONEach: QueryRepresentable {
  public typealias QueryOutput = JSONEach
}

extension JSONEach: QueryDecodable {
  public init(decoder: inout some QueryDecoder) throws {
    self.key = try Key(decoder: &decoder).queryOutput
    self.value = try Value(decoder: &decoder).queryOutput
  }
}

extension JSONEach: Sendable where Key.QueryOutput: Sendable, Value.QueryOutput: Sendable {}

extension JSONEach: Equatable where Key.QueryOutput: Equatable, Value.QueryOutput: Equatable {}

public struct JSONBEach<
  Key: QueryRepresentable & QueryBindable,
  Value: QueryRepresentable & QueryBindable
>: Table {
  public static var tableName: String { "jsonb_each" }

  public static var columns: TableColumns { TableColumns() }

  public static var _columnWidth: Int { 2 }

  public let key: Key.QueryOutput

  public let value: Value.QueryOutput

  fileprivate static func select(from tableReference: ISO_9075.Fragment) -> SelectOf<JSONBEach> {
    var select = all.asSelect()
    select._tableReference = tableReference
    return select
  }

  public struct TableColumns: TableDefinition, Sendable {
    public typealias QueryValue = JSONBEach

    public static var allColumns: [any TableColumnExpression] {
      [TableColumns().key, TableColumns().value]
    }

    public static var writableColumns: [any WritableTableColumnExpression] { [] }

    public var key: GeneratedColumn<JSONBEach, Key> {
      GeneratedColumn("key", keyPath: \JSONBEach.key)
    }

    public var value: GeneratedColumn<JSONBEach, Value> {
      GeneratedColumn("value", keyPath: \JSONBEach.value)
    }
  }

  public struct Selection: TableExpression {
    public typealias QueryValue = JSONBEach

    public var allColumns: [any QueryExpression]

    public init(allColumns: [any QueryExpression]) {
      self.allColumns = allColumns
    }
  }
}

extension JSONBEach: QueryRepresentable {
  public typealias QueryOutput = JSONBEach
}

extension JSONBEach: QueryDecodable {
  public init(decoder: inout some QueryDecoder) throws {
    self.key = try Key(decoder: &decoder).queryOutput
    self.value = try Value(decoder: &decoder).queryOutput
  }
}

extension JSONBEach: Sendable where Key.QueryOutput: Sendable, Value.QueryOutput: Sendable {}

extension JSONBEach: Equatable where Key.QueryOutput: Equatable, Value.QueryOutput: Equatable {}

extension QueryExpression {
  fileprivate var argumentFragment: ISO_9075.Fragment {
    $_isSelecting.withValue(false) { queryFragment }
  }

  fileprivate func jsonEachFragment<Root, Context, Member>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>
  ) -> ISO_9075.Fragment {
    eachFragment("json_each", path)
  }

  fileprivate func jsonbEachFragment<Root, Context, Member>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>
  ) -> ISO_9075.Fragment {
    eachFragment("jsonb_each", path)
  }

  private func eachFragment<Root, Context, Member>(
    _ function: ISO_9075.Fragment,
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>
  ) -> ISO_9075.Fragment {
    """
    \(function)(\
    \(argumentFragment), \
    \(text: JSONPath()[keyPath: path].pathString)\
    )
    """
  }
}
