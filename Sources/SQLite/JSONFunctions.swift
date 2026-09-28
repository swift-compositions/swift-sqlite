public import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonExtract<Context, Member: QueryRepresentable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> some QueryExpression<Member> {
    _jsonExtract(path)
  }

  @_documentation(visibility: private)
  public func jsonExtract<
    Context: _OptionalJSONPathContext,
    Member: QueryRepresentable
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> some QueryExpression<Member._Optionalized> {
    _jsonExtract(path)
  }

  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue.QueryOutput]>> {
    _jsonGroupArray(isDistinct: isDistinct, order: Bool?.none, filter: filter)
  }

  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue.QueryOutput]>> {
    _jsonGroupArray(isDistinct: isDistinct, order: order, filter: filter)
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonbExtract<Context, Member: QueryRepresentable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> some QueryExpression<Member> {
    _jsonbExtract(path)
  }

  @_documentation(visibility: private)
  public func jsonbExtract<
    Context: _OptionalJSONPathContext,
    Member: QueryRepresentable
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> some QueryExpression<Member._Optionalized> {
    _jsonbExtract(path)
  }

  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue.QueryOutput]>> {
    _jsonbGroupArray(isDistinct: isDistinct, order: Bool?.none, filter: filter)
  }

  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue.QueryOutput]>> {
    _jsonbGroupArray(isDistinct: isDistinct, order: order, filter: filter)
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonSet<Context: _RequiredJSONPathContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONSetExpression(
      function: "json_set",
      base: argumentFragment,
      arguments: [.jsonSetArguments("json_object", path, .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonSet<Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<_JSONPathCase, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONSetExpression(
      function: "json_set",
      base: argumentFragment,
      arguments: [.jsonSetArguments("json_object", path, .jsonEncoded(value))]
    )
  }

  public func jsonInsert<Member: QueryBindable & SQL::_OptionalProtocol>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<_JSONPathMember, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONInsertExpression<JSONRepresentation<QueryValue.QueryOutput>>
  where Member.Wrapped: QueryBindable {
    _JSONInsertExpression(
      function: "json_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }

  public func jsonAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member._Element>
  ) -> _JSONInsertExpression<JSONRepresentation<QueryValue.QueryOutput>>
  where Member._Element: QueryBindable {
    _JSONInsertExpression(
      function: "json_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member._ElementRepresentation>
  ) -> _JSONInsertExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONInsertExpression(
      function: "json_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped._Element>
  ) -> _JSONInsertExpression<JSONRepresentation<QueryValue.QueryOutput>>
  where Member.Wrapped: _JSONArrayRepresentation, Member.Wrapped._Element: QueryBindable {
    _JSONInsertExpression(
      function: "json_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped._ElementRepresentation>
  ) -> _JSONInsertExpression<JSONRepresentation<QueryValue.QueryOutput>>
  where Member.Wrapped: _JSONArrayRepresentation {
    _JSONInsertExpression(
      function: "json_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  public func jsonRemove<
    Context: _JSONPathMemberContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> _JSONRemoveExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONRemoveExpression(
      function: "json_remove",
      base: argumentFragment,
      arguments: [.jsonArguments(path)]
    )
  }

  public func jsonRemove<Context: _JSONPathElementContext, Member>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> _JSONRemoveExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONRemoveExpression(
      function: "json_remove",
      base: argumentFragment,
      arguments: [.jsonArguments(path)]
    )
  }

  public func jsonReplace<Context: _JSONPathMemberContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONReplaceExpression<JSONRepresentation<QueryValue.QueryOutput>>
  where Member: SQL::_OptionalProtocol, Member.Wrapped: QueryBindable {
    _JSONReplaceExpression(
      function: "json_replace",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }

  public func jsonReplace<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONReplaceExpression(
      function: "json_replace",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }

  @_disfavoredOverload
  @_documentation(visibility: private)
  public func jsonReplace<
    Context: _JSONPathMemberContext & _OptionalJSONPathContext, Member: QueryBindable
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONReplaceExpression(
      function: "json_replace",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }
}

extension QueryExpression
where QueryValue: _AnyJSONRepresentable & _JSONArrayRepresentation {
  public func jsonArrayLength() -> some QueryExpression<Int> {
    SQLQueryExpression("json_array_length(\(argumentFragment))")
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonArrayLength<Context, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> some QueryExpression<Int> {
    _jsonArrayLength(path)
  }

  @_documentation(visibility: private)
  public func jsonArrayLength<
    Context: _OptionalJSONPathContext,
    Member: _JSONArrayRepresentation
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> some QueryExpression<Int?> {
    _jsonArrayLength(path)
  }

  @_documentation(visibility: private)
  public func jsonArrayLength<Context, Member: SQL::_OptionalProtocol>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> some QueryExpression<Int?>
  where Member.Wrapped: _JSONArrayRepresentation {
    _jsonArrayLength(path)
  }
}

extension QueryExpression
where
  QueryValue: _AnyJSONRepresentable,
  QueryValue.QueryOutput: RangeReplaceableCollection,
  QueryValue.QueryOutput.Element: Codable
{
  public func jsonAppend(
    _ value: some QueryExpression<QueryValue.QueryOutput.Element>
  ) -> _JSONInsertExpression<JSONRepresentation<QueryValue.QueryOutput>>
  where QueryValue.QueryOutput.Element: QueryBindable {
    jsonAppend(\.self, value)
  }

  @_documentation(visibility: private)
  public func jsonAppend(
    _ value: some QueryExpression<JSONRepresentation<QueryValue.QueryOutput.Element>>
  ) -> _JSONInsertExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    jsonAppend(\.self, value)
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonArrayInsert<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONArrayInsertExpression<JSONRepresentation<QueryValue.QueryOutput>> {
    _JSONArrayInsertExpression(
      function: "json_array_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonbSet<Context: _RequiredJSONPathContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONSetExpression(
      function: "jsonb_set",
      base: argumentFragment,
      arguments: [.jsonSetArguments("jsonb_object", path, .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonbSet<Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<_JSONPathCase, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONSetExpression(
      function: "jsonb_set",
      base: argumentFragment,
      arguments: [.jsonSetArguments("jsonb_object", path, .jsonEncoded(value))]
    )
  }

  public func jsonbInsert<Member: QueryBindable & SQL::_OptionalProtocol>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<_JSONPathMember, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>>
  where Member.Wrapped: QueryBindable {
    _JSONInsertExpression(
      function: "jsonb_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }

  public func jsonbAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member._Element>
  ) -> _JSONInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>>
  where Member._Element: QueryBindable {
    _JSONInsertExpression(
      function: "jsonb_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonbAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member._ElementRepresentation>
  ) -> _JSONInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONInsertExpression(
      function: "jsonb_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonbAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped._Element>
  ) -> _JSONInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>>
  where Member.Wrapped: _JSONArrayRepresentation, Member.Wrapped._Element: QueryBindable {
    _JSONInsertExpression(
      function: "jsonb_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  @_documentation(visibility: private)
  public func jsonbAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped._ElementRepresentation>
  ) -> _JSONInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>>
  where Member.Wrapped: _JSONArrayRepresentation {
    _JSONInsertExpression(
      function: "jsonb_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, appending: "[#]", .jsonEncoded(value))]
    )
  }

  public func jsonbRemove<
    Context: _JSONPathMemberContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> _JSONRemoveExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONRemoveExpression(
      function: "jsonb_remove",
      base: argumentFragment,
      arguments: [.jsonArguments(path)]
    )
  }

  public func jsonbRemove<Context: _JSONPathElementContext, Member>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >
  ) -> _JSONRemoveExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONRemoveExpression(
      function: "jsonb_remove",
      base: argumentFragment,
      arguments: [.jsonArguments(path)]
    )
  }

  public func jsonbReplace<Context: _JSONPathMemberContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONReplaceExpression<JSONBRepresentation<QueryValue.QueryOutput>>
  where Member: SQL::_OptionalProtocol, Member.Wrapped: QueryBindable {
    _JSONReplaceExpression(
      function: "jsonb_replace",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }

  public func jsonbReplace<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONReplaceExpression(
      function: "jsonb_replace",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }

  @_disfavoredOverload
  @_documentation(visibility: private)
  public func jsonbReplace<
    Context: _JSONPathMemberContext & _OptionalJSONPathContext, Member: QueryBindable
  >(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONReplaceExpression(
      function: "jsonb_replace",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }
}

extension QueryExpression
where
  QueryValue: _AnyJSONRepresentable,
  QueryValue.QueryOutput: RangeReplaceableCollection,
  QueryValue.QueryOutput.Element: Codable
{
  public func jsonbAppend(
    _ value: some QueryExpression<QueryValue.QueryOutput.Element>
  ) -> _JSONInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>>
  where QueryValue.QueryOutput.Element: QueryBindable {
    jsonbAppend(\.self, value)
  }

  @_documentation(visibility: private)
  public func jsonbAppend(
    _ value: some QueryExpression<JSONBRepresentation<QueryValue.QueryOutput.Element>>
  ) -> _JSONInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    jsonbAppend(\.self, value)
  }
}

extension QueryExpression where QueryValue: _AnyJSONRepresentable {
  public func jsonbArrayInsert<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<
      JSONPath<_JSONPathRoot, JSONBRepresentation<QueryValue.QueryOutput>>,
      JSONPath<Context, Member>
    >,
    _ value: some QueryExpression<Member>
  ) -> _JSONArrayInsertExpression<JSONBRepresentation<QueryValue.QueryOutput>> {
    _JSONArrayInsertExpression(
      function: "jsonb_array_insert",
      base: argumentFragment,
      arguments: [.jsonArguments(path, .jsonEncoded(value))]
    )
  }
}

extension QueryExpression
where QueryValue: SQL::_OptionalProtocol, QueryValue.Wrapped: _AnyJSONRepresentable
{
  public func jsonExtract<Context, Member: QueryRepresentable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue.Wrapped>, JSONPath<Context, Member>>
  ) -> some QueryExpression<Member._Optionalized> {
    _jsonExtract(path)
  }

  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue.Wrapped.QueryOutput?]>> {
    _jsonGroupArray(isDistinct: isDistinct, order: Bool?.none, filter: filter)
  }

  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue.Wrapped.QueryOutput?]>> {
    _jsonGroupArray(isDistinct: isDistinct, order: order, filter: filter)
  }
}

extension QueryExpression
where QueryValue: SQL::_OptionalProtocol, QueryValue.Wrapped: _AnyJSONRepresentable
{
  public func jsonbExtract<Context, Member: QueryRepresentable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue.Wrapped>, JSONPath<Context, Member>>
  ) -> some QueryExpression<Member._Optionalized> {
    _jsonbExtract(path)
  }

  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue.Wrapped.QueryOutput?]>> {
    _jsonbGroupArray(isDistinct: isDistinct, order: Bool?.none, filter: filter)
  }

  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue.Wrapped.QueryOutput?]>> {
    _jsonbGroupArray(isDistinct: isDistinct, order: order, filter: filter)
  }
}

extension QueryExpression {
  fileprivate var argumentFragment: ISO_9075.Fragment {
    $_isSelecting.withValue(false) { queryFragment }
  }

  private func _jsonExtract<Root, Context, Member: QueryRepresentable, Result>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>
  ) -> SQLQueryExpression<Result> {
    SQLQueryExpression(_jsonExtract("json_extract", path))
  }

  private func _jsonbExtract<Root, Context, Member: QueryRepresentable, Result>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>
  ) -> JSONFunctionExpression<Result> {
    JSONFunctionExpression(
      base: _jsonExtract("jsonb_extract", path),
      decode: Member.queryFragment(decoding:)
    )
  }

  private func _jsonArrayLength<Root, Context, Member, Result>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>
  ) -> SQLQueryExpression<Result> {
    SQLQueryExpression(
      """
      json_array_length(\
      \(argumentFragment), \
      \(text: JSONPath()[keyPath: path].pathString)\
      )
      """
    )
  }

  private func _jsonExtract<Root, Context, Member: QueryRepresentable>(
    _ function: ISO_9075.Fragment,
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>
  ) -> ISO_9075.Fragment {
    Member._queryFragment(
      jsonDecoding: """
        \(function)(\
        \(argumentFragment), \
        \(text: JSONPath()[keyPath: path].pathString)\
        )
        """
    )
  }

  private func _jsonGroupArray<Result>(
    isDistinct: Bool,
    order: (some QueryExpression)?,
    filter: (some QueryExpression<Bool>)?
  ) -> AggregateFunctionExpression<Result> {
    AggregateFunctionExpression(
      "json_group_array",
      distinct: isDistinct,
      ["json(\(argumentFragment))"],
      order: order?.queryFragment,
      filter: filter?.queryFragment
    )
  }

  private func _jsonbGroupArray<Result>(
    isDistinct: Bool,
    order: (some QueryExpression)?,
    filter: (some QueryExpression<Bool>)?
  ) -> AggregateFunctionExpression<Result> {
    AggregateFunctionExpression(
      "jsonb_group_array",
      distinct: isDistinct,
      ["jsonb(\(argumentFragment))"],
      order: order?.queryFragment,
      filter: filter?.queryFragment
    )
  }
}

extension QueryExpression where QueryValue: Codable & QueryBindable {
  @_disfavoredOverload
  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "json_group_array",
      distinct: isDistinct,
      [queryFragment],
      filter: filter?.queryFragment
    )
  }

  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "json_group_array",
      distinct: isDistinct,
      [queryFragment],
      order: order.queryFragment,
      filter: filter?.queryFragment
    )
  }
}

extension QueryExpression where QueryValue: Codable & QueryBindable {
  @_disfavoredOverload
  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "jsonb_group_array",
      distinct: isDistinct,
      [queryFragment],
      filter: filter?.queryFragment
    )
  }

  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "jsonb_group_array",
      distinct: isDistinct,
      [queryFragment],
      order: order.queryFragment,
      filter: filter?.queryFragment
    )
  }
}

extension TableDefinition where QueryValue: Codable {
  @_disfavoredOverload
  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "json_group_array",
      distinct: isDistinct,
      [jsonObject().queryFragment],
      filter: filter?.queryFragment
    )
  }

  @_disfavoredOverload
  public func jsonGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "json_group_array",
      distinct: isDistinct,
      [jsonObject().queryFragment],
      order: order.queryFragment,
      filter: filter?.queryFragment
    )
  }
}

extension TableDefinition where QueryValue: Codable {
  @_disfavoredOverload
  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "jsonb_group_array",
      distinct: isDistinct,
      [jsonbObject().queryFragment],
      filter: filter?.queryFragment
    )
  }

  @_disfavoredOverload
  public func jsonbGroupArray(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[QueryValue]>> {
    AggregateFunctionExpression(
      "jsonb_group_array",
      distinct: isDistinct,
      [jsonbObject().queryFragment],
      order: order.queryFragment,
      filter: filter?.queryFragment
    )
  }
}

extension TableDefinition where QueryValue: SQL::_OptionalProtocol & Codable {
  public func jsonGroupArray<Wrapped: Codable>(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[Wrapped]>>
  where QueryValue == Wrapped? {
    let rowFilter = rowid.isNot(nil)
    let filterQueryFragment =
      if let filter {
        rowFilter.and(filter).queryFragment
      } else {
        rowFilter.queryFragment
      }
    return _jsonGroupArray(isDistinct: isDistinct, order: nil, filter: filterQueryFragment)
  }

  public func jsonGroupArray<Wrapped: Codable>(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONRepresentation<[Wrapped]>>
  where QueryValue == Wrapped? {
    let rowFilter = rowid.isNot(nil)
    let filterQueryFragment =
      if let filter {
        rowFilter.and(filter).queryFragment
      } else {
        rowFilter.queryFragment
      }
    return _jsonGroupArray(
      isDistinct: isDistinct,
      order: order.queryFragment,
      filter: filterQueryFragment
    )
  }

  fileprivate func _jsonGroupArray<Wrapped: Codable>(
    isDistinct: Bool,
    order: ISO_9075.Fragment?,
    filter: ISO_9075.Fragment?
  ) -> AggregateFunctionExpression<JSONRepresentation<[Wrapped]>>
  where QueryValue == Wrapped? {
    AggregateFunctionExpression(
      "json_group_array",
      distinct: isDistinct,
      [QueryValue.columns.jsonObject().queryFragment],
      order: order,
      filter: filter
    )
  }
}

extension TableDefinition where QueryValue: SQL::_OptionalProtocol & Codable {
  public func jsonbGroupArray<Wrapped: Codable>(
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[Wrapped]>>
  where QueryValue == Wrapped? {
    let rowFilter = rowid.isNot(nil)
    let filterQueryFragment =
      if let filter {
        rowFilter.and(filter).queryFragment
      } else {
        rowFilter.queryFragment
      }
    return _jsonbGroupArray(isDistinct: isDistinct, order: nil, filter: filterQueryFragment)
  }

  public func jsonbGroupArray<Wrapped: Codable>(
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<JSONBRepresentation<[Wrapped]>>
  where QueryValue == Wrapped? {
    let rowFilter = rowid.isNot(nil)
    let filterQueryFragment =
      if let filter {
        rowFilter.and(filter).queryFragment
      } else {
        rowFilter.queryFragment
      }
    return _jsonbGroupArray(
      isDistinct: isDistinct,
      order: order.queryFragment,
      filter: filterQueryFragment
    )
  }

  fileprivate func _jsonbGroupArray<Wrapped: Codable>(
    isDistinct: Bool,
    order: ISO_9075.Fragment?,
    filter: ISO_9075.Fragment?
  ) -> AggregateFunctionExpression<JSONBRepresentation<[Wrapped]>>
  where QueryValue == Wrapped? {
    AggregateFunctionExpression(
      "jsonb_group_array",
      distinct: isDistinct,
      [QueryValue.columns.jsonbObject().queryFragment],
      order: order,
      filter: filter
    )
  }
}

extension TableDefinition where QueryValue: Codable {
  public func jsonObject() -> some QueryExpression<JSONRepresentation<QueryValue>> {
    QueryFunction("json_object", SQLQueryExpression(_jsonObjectArguments))
  }

  fileprivate var _jsonObjectArguments: ISO_9075.Fragment {
    $_isSelecting.withValue(false) {
      Self.allColumns
        .map { "\(text: $0.name), \($0.jsonEncoding($0.queryFragment))" as ISO_9075.Fragment }
        .joined(separator: ", ")
    }
  }
}

extension TableDefinition where QueryValue: Codable {
  public func jsonbObject() -> some QueryExpression<JSONBRepresentation<QueryValue>> {
    QueryFunction("jsonb_object", SQLQueryExpression(_jsonObjectArguments))
  }
}

extension Optional.TableColumns where QueryValue: Codable {
  public func jsonObject() -> some QueryExpression<JSONRepresentation<Wrapped>?> {
    Case().when(rowid.isNot(nil), then: Wrapped.columns.jsonObject())
  }
}

extension Optional.TableColumns where QueryValue: Codable {
  public func jsonbObject() -> some QueryExpression<JSONBRepresentation<Wrapped>?> {
    Case().when(rowid.isNot(nil), then: Wrapped.columns.jsonbObject())
  }
}

@dynamicMemberLookup
public struct JSONPath<Context, QueryValue> {
  var components: [String] = []
  var caseName: String?

  var pathString: String {
    "$\(components.joined())"
  }

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<
      QueryValue._Object.TableColumns, TableColumn<QueryValue._Object, Member>
    >
  ) -> JSONPath<Context._Member, Member>
  where Context: _JSONPathContext, QueryValue: _JSONObjectRepresentation {
    JSONPath<Context._Member, Member>(
      components: components + [.member(QueryValue._Object.columns[keyPath: keyPath].name)]
    )
  }

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<
      QueryValue._Object.TableColumns, TableColumn<QueryValue._Object, Member>
    >
  ) -> JSONPath<Context._Member, Member.QueryOutput>
  where
    Context: _JSONPathContext,
    QueryValue: _JSONObjectRepresentation,
    Member.QueryOutput: QueryBindable
  {
    JSONPath<Context._Member, Member.QueryOutput>(
      components: components + [.member(QueryValue._Object.columns[keyPath: keyPath].name)]
    )
  }

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<
      QueryValue.Wrapped._Object.TableColumns, TableColumn<QueryValue.Wrapped._Object, Member>
    >
  ) -> JSONPath<_JSONPathMember?, Member>
  where
    QueryValue: SQL::_OptionalProtocol,
    QueryValue.Wrapped: _JSONObjectRepresentation
  {
    JSONPath<_JSONPathMember?, Member>(
      components: components + [.member(QueryValue.Wrapped._Object.columns[keyPath: keyPath].name)]
    )
  }

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<
      QueryValue.Wrapped._Object.TableColumns, TableColumn<QueryValue.Wrapped._Object, Member>
    >
  ) -> JSONPath<_JSONPathMember?, Member.QueryOutput>
  where
    QueryValue: SQL::_OptionalProtocol,
    QueryValue.Wrapped: _JSONObjectRepresentation,
    Member.QueryOutput: QueryBindable
  {
    JSONPath<_JSONPathMember?, Member.QueryOutput>(
      components: components + [.member(QueryValue.Wrapped._Object.columns[keyPath: keyPath].name)]
    )
  }

  public subscript(_ index: Int) -> JSONPath<Context._Element, QueryValue._ElementRepresentation>
  where Context: _JSONPathContext, QueryValue: _JSONArrayRepresentation {
    JSONPath<Context._Element, QueryValue._ElementRepresentation>(
      components: components + [.index(index)]
    )
  }

  public subscript(_ index: Int) -> JSONPath<Context._Element, QueryValue._Element>
  where
    Context: _JSONPathContext,
    QueryValue: _JSONArrayRepresentation,
    QueryValue._Element: QueryBindable
  {
    JSONPath<Context._Element, QueryValue._Element>(components: components + [.index(index)])
  }

  public subscript(
    _ index: Int
  ) -> JSONPath<_JSONPathElement?, QueryValue.Wrapped._ElementRepresentation>
  where
    QueryValue: SQL::_OptionalProtocol,
    QueryValue.Wrapped: _JSONArrayRepresentation
  {
    JSONPath<_JSONPathElement?, QueryValue.Wrapped._ElementRepresentation>(
      components: components + [.index(index)]
    )
  }

  public subscript(_ index: Int) -> JSONPath<_JSONPathElement?, QueryValue.Wrapped._Element>
  where
    QueryValue: SQL::_OptionalProtocol,
    QueryValue.Wrapped: _JSONArrayRepresentation,
    QueryValue.Wrapped._Element: QueryBindable
  {
    JSONPath<_JSONPathElement?, QueryValue.Wrapped._Element>(
      components: components + [.index(index)]
    )
  }

  public subscript<Object: Table & Codable, Member: Table & Codable>(
    dynamicMember keyPath: KeyPath<Object.TableColumns, ColumnGroup<Object, Member>>
  ) -> JSONPath<Context._Member, JSONRepresentation<Member>>
  where
    Context: _JSONPathContext,
    QueryValue == JSONRepresentation<Object>,
    Member.QueryOutput == Member,
    Member._Optionalized == Member?
  {
    JSONPath<Context._Member, JSONRepresentation<Member>>(
      components: components + [.member(Object.columns[keyPath: keyPath].groupName)]
    )
  }

  public subscript<Object: Table & Codable, Member: Table & Codable>(
    dynamicMember keyPath: KeyPath<Object.TableColumns, ColumnGroup<Object, Member?>>
  ) -> JSONPath<Context._Member, JSONRepresentation<Member>?>
  where
    Context: _JSONPathContext,
    QueryValue == JSONRepresentation<Object>,
    Member.QueryOutput == Member
  {
    JSONPath<Context._Member, JSONRepresentation<Member>?>(
      components: components + [.member(Object.columns[keyPath: keyPath].groupName)]
    )
  }

  public subscript<Object: Table & Codable, Member: Table & Codable>(
    dynamicMember keyPath: KeyPath<Object.TableColumns, ColumnGroup<Object, Member>>
  ) -> JSONPath<Context._Member, JSONBRepresentation<Member>>
  where
    Context: _JSONPathContext,
    QueryValue == JSONBRepresentation<Object>,
    Member.QueryOutput == Member,
    Member._Optionalized == Member?
  {
    JSONPath<Context._Member, JSONBRepresentation<Member>>(
      components: components + [.member(Object.columns[keyPath: keyPath].groupName)]
    )
  }

  public subscript<Object: Table & Codable, Member: Table & Codable>(
    dynamicMember keyPath: KeyPath<Object.TableColumns, ColumnGroup<Object, Member?>>
  ) -> JSONPath<Context._Member, JSONBRepresentation<Member>?>
  where
    Context: _JSONPathContext,
    QueryValue == JSONBRepresentation<Object>,
    Member.QueryOutput == Member
  {
    JSONPath<Context._Member, JSONBRepresentation<Member>?>(
      components: components + [.member(Object.columns[keyPath: keyPath].groupName)]
    )
  }

  #if CasePaths
    public subscript<Member>(
      dynamicMember keyPath: KeyPath<
        QueryValue._Object.TableColumns, CaseColumn<QueryValue._Object, Member>
      >
    ) -> JSONPath<Context._Case, Member>
    where Context: _JSONPathContext, QueryValue: _JSONObjectRepresentation {
      let name = QueryValue._Object.columns[keyPath: keyPath].name
      return JSONPath<Context._Case, Member>(
        components: components + [.member(name)],
        caseName: name
      )
    }

    public subscript<Member>(
      dynamicMember keyPath: KeyPath<
        QueryValue._Object.TableColumns, CaseColumn<QueryValue._Object, Member>
      >
    ) -> JSONPath<Context._Case, Member.QueryOutput>
    where
      Context: _JSONPathContext,
      QueryValue: _JSONObjectRepresentation,
      Member.QueryOutput: QueryBindable
    {
      let name = QueryValue._Object.columns[keyPath: keyPath].name
      return JSONPath<Context._Case, Member.QueryOutput>(
        components: components + [.member(name)],
        caseName: name
      )
    }

    public subscript<Member>(
      dynamicMember keyPath: KeyPath<
        QueryValue.Wrapped._Object.TableColumns, CaseColumn<QueryValue.Wrapped._Object, Member>
      >
    ) -> JSONPath<_JSONPathCase?, Member>
    where
      QueryValue: SQL::_OptionalProtocol,
      QueryValue.Wrapped: _JSONObjectRepresentation
    {
      let name = QueryValue.Wrapped._Object.columns[keyPath: keyPath].name
      return JSONPath<_JSONPathCase?, Member>(
        components: components + [.member(name)],
        caseName: name
      )
    }

    public subscript<Member>(
      dynamicMember keyPath: KeyPath<
        QueryValue.Wrapped._Object.TableColumns, CaseColumn<QueryValue.Wrapped._Object, Member>
      >
    ) -> JSONPath<_JSONPathCase?, Member.QueryOutput>
    where
      QueryValue: SQL::_OptionalProtocol,
      QueryValue.Wrapped: _JSONObjectRepresentation,
      Member.QueryOutput: QueryBindable
    {
      let name = QueryValue.Wrapped._Object.columns[keyPath: keyPath].name
      return JSONPath<_JSONPathCase?, Member.QueryOutput>(
        components: components + [.member(name)],
        caseName: name
      )
    }

    public subscript<Object: Table & Codable, Member: Table & Codable>(
      dynamicMember keyPath: KeyPath<Object.TableColumns, CaseColumnGroup<Object, Member>>
    ) -> JSONPath<Context._Case, JSONRepresentation<Member>>
    where
      Context: _JSONPathContext,
      QueryValue == JSONRepresentation<Object>,
      Member.QueryOutput == Member
    {
      let name = Object.columns[keyPath: keyPath].name
      return JSONPath<Context._Case, JSONRepresentation<Member>>(
        components: components + [.member(name)],
        caseName: name
      )
    }

    public subscript<Object: Table & Codable, Member: Table & Codable>(
      dynamicMember keyPath: KeyPath<Object.TableColumns, CaseColumnGroup<Object, Member>>
    ) -> JSONPath<Context._Case, JSONBRepresentation<Member>>
    where
      Context: _JSONPathContext,
      QueryValue == JSONBRepresentation<Object>,
      Member.QueryOutput == Member
    {
      let name = Object.columns[keyPath: keyPath].name
      return JSONPath<Context._Case, JSONBRepresentation<Member>>(
        components: components + [.member(name)],
        caseName: name
      )
    }
  #endif
}

private struct JSONFunctionExpression<QueryValue>: QueryExpression {
  let base: ISO_9075.Fragment
  let decode: (ISO_9075.Fragment) -> ISO_9075.Fragment

  var queryFragment: ISO_9075.Fragment {
    _isSelecting ? decode(base) : base
  }
}

private protocol _JSONMutationExpression: QueryExpression
where QueryValue: QueryRepresentable {
  var function: ISO_9075.Fragment { get }
  var base: ISO_9075.Fragment { get }
  var arguments: [ISO_9075.Fragment] { get }
  init(function: ISO_9075.Fragment, base: ISO_9075.Fragment, arguments: [ISO_9075.Fragment])
}

extension _JSONMutationExpression {
  public var queryFragment: ISO_9075.Fragment {
    let fragment: ISO_9075.Fragment =
      "\(function)(\(base), \(arguments.joined(separator: ", ")))"
    return _isSelecting ? QueryValue.queryFragment(decoding: fragment) : fragment
  }

  fileprivate func appending(_ argument: ISO_9075.Fragment) -> Self {
    Self(function: function, base: base, arguments: arguments + [argument])
  }
}

public struct _JSONInsertExpression<QueryValue: QueryRepresentable>: _JSONMutationExpression {
  let function: ISO_9075.Fragment
  let base: ISO_9075.Fragment
  let arguments: [ISO_9075.Fragment]
}

extension _JSONInsertExpression where QueryValue: _JSONRepresentable {
  public func jsonInsert<Member: QueryBindable & SQL::_OptionalProtocol>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<_JSONPathMember, Member>>,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONInsertExpression<QueryValue>
  where Member.Wrapped: QueryBindable {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }

  public func jsonAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member._Element>
  ) -> _JSONInsertExpression<QueryValue>
  where Member._Element: QueryBindable {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }

  public func jsonAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member._ElementRepresentation>
  ) -> _JSONInsertExpression<QueryValue> {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }

  public func jsonAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member.Wrapped._Element>
  ) -> _JSONInsertExpression<QueryValue>
  where Member.Wrapped: _JSONArrayRepresentation, Member.Wrapped._Element: QueryBindable {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }

  public func jsonAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member.Wrapped._ElementRepresentation>
  ) -> _JSONInsertExpression<QueryValue>
  where Member.Wrapped: _JSONArrayRepresentation {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }
}

extension _JSONInsertExpression
where QueryValue: _JSONRepresentable & _JSONArrayRepresentation {
  public func jsonAppend(
    _ value: some QueryExpression<QueryValue._Element>
  ) -> _JSONInsertExpression<QueryValue>
  where QueryValue._Element: QueryBindable {
    jsonAppend(\.self, value)
  }

  public func jsonAppend(
    _ value: some QueryExpression<QueryValue._ElementRepresentation>
  ) -> _JSONInsertExpression<QueryValue> {
    jsonAppend(\.self, value)
  }
}

extension _JSONInsertExpression where QueryValue: _JSONBRepresentable {
  public func jsonbInsert<Member: QueryBindable & SQL::_OptionalProtocol>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<_JSONPathMember, Member>>,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONInsertExpression<QueryValue>
  where Member.Wrapped: QueryBindable {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }

  public func jsonbAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member._Element>
  ) -> _JSONInsertExpression<QueryValue>
  where Member._Element: QueryBindable {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }

  public func jsonbAppend<Context: _RequiredJSONPathContext, Member: _JSONArrayRepresentation>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member._ElementRepresentation>
  ) -> _JSONInsertExpression<QueryValue> {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }

  public func jsonbAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member.Wrapped._Element>
  ) -> _JSONInsertExpression<QueryValue>
  where Member.Wrapped: _JSONArrayRepresentation, Member.Wrapped._Element: QueryBindable {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }

  public func jsonbAppend<
    Context: _RequiredJSONPathContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member.Wrapped._ElementRepresentation>
  ) -> _JSONInsertExpression<QueryValue>
  where Member.Wrapped: _JSONArrayRepresentation {
    appending(.jsonArguments(path, appending: "[#]", .jsonEncoded(value)))
  }
}

extension _JSONInsertExpression
where QueryValue: _JSONBRepresentable & _JSONArrayRepresentation {
  public func jsonbAppend(
    _ value: some QueryExpression<QueryValue._Element>
  ) -> _JSONInsertExpression<QueryValue>
  where QueryValue._Element: QueryBindable {
    jsonbAppend(\.self, value)
  }

  public func jsonbAppend(
    _ value: some QueryExpression<QueryValue._ElementRepresentation>
  ) -> _JSONInsertExpression<QueryValue> {
    jsonbAppend(\.self, value)
  }
}

public struct _JSONArrayInsertExpression<QueryValue: QueryRepresentable>: _JSONMutationExpression {
  let function: ISO_9075.Fragment
  let base: ISO_9075.Fragment
  let arguments: [ISO_9075.Fragment]
}

extension _JSONArrayInsertExpression where QueryValue: _JSONRepresentable {
  public func jsonArrayInsert<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONArrayInsertExpression<QueryValue> {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }
}

extension _JSONArrayInsertExpression where QueryValue: _JSONBRepresentable {
  public func jsonbArrayInsert<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONArrayInsertExpression<QueryValue> {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }
}

public struct _JSONRemoveExpression<QueryValue: QueryRepresentable>: _JSONMutationExpression {
  let function: ISO_9075.Fragment
  let base: ISO_9075.Fragment
  let arguments: [ISO_9075.Fragment]
}

extension _JSONRemoveExpression where QueryValue: _JSONRepresentable {
  public func jsonRemove<
    Context: _JSONPathMemberContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> _JSONRemoveExpression<QueryValue> {
    appending(.jsonArguments(path))
  }

  public func jsonRemove<Context: _JSONPathElementContext, Member>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> _JSONRemoveExpression<QueryValue> {
    appending(.jsonArguments(path))
  }
}

extension _JSONRemoveExpression where QueryValue: _JSONBRepresentable {
  public func jsonbRemove<
    Context: _JSONPathMemberContext, Member: SQL::_OptionalProtocol
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> _JSONRemoveExpression<QueryValue> {
    appending(.jsonArguments(path))
  }

  public func jsonbRemove<Context: _JSONPathElementContext, Member>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>
  ) -> _JSONRemoveExpression<QueryValue> {
    appending(.jsonArguments(path))
  }
}

public struct _JSONReplaceExpression<QueryValue: QueryRepresentable>: _JSONMutationExpression {
  let function: ISO_9075.Fragment
  let base: ISO_9075.Fragment
  let arguments: [ISO_9075.Fragment]
}

extension _JSONReplaceExpression where QueryValue: _JSONRepresentable {
  public func jsonReplace<Context: _JSONPathMemberContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONReplaceExpression<QueryValue>
  where Member: SQL::_OptionalProtocol, Member.Wrapped: QueryBindable {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }

  public func jsonReplace<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<QueryValue> {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }

  @_disfavoredOverload
  public func jsonReplace<
    Context: _JSONPathMemberContext & _OptionalJSONPathContext, Member: QueryBindable
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<QueryValue> {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }
}

extension _JSONReplaceExpression where QueryValue: _JSONBRepresentable {
  public func jsonbReplace<Context: _JSONPathMemberContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member.Wrapped>
  ) -> _JSONReplaceExpression<QueryValue>
  where Member: SQL::_OptionalProtocol, Member.Wrapped: QueryBindable {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }

  public func jsonbReplace<Context: _JSONPathElementContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<QueryValue> {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }

  @_disfavoredOverload
  public func jsonbReplace<
    Context: _JSONPathMemberContext & _OptionalJSONPathContext, Member: QueryBindable
  >(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONReplaceExpression<QueryValue> {
    appending(.jsonArguments(path, .jsonEncoded(value)))
  }
}

public struct _JSONSetExpression<QueryValue: QueryRepresentable>: _JSONMutationExpression {
  let function: ISO_9075.Fragment
  let base: ISO_9075.Fragment
  let arguments: [ISO_9075.Fragment]
}

extension _JSONSetExpression where QueryValue: _JSONRepresentable {
  public func jsonSet<Context: _RequiredJSONPathContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<QueryValue> {
    appending(.jsonSetArguments("json_object", path, .jsonEncoded(value)))
  }

  public func jsonSet<Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<_JSONPathCase, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<QueryValue> {
    appending(.jsonSetArguments("json_object", path, .jsonEncoded(value)))
  }
}

extension _JSONSetExpression where QueryValue: _JSONBRepresentable {
  public func jsonbSet<Context: _RequiredJSONPathContext, Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<Context, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<QueryValue> {
    appending(.jsonSetArguments("jsonb_object", path, .jsonEncoded(value)))
  }

  public func jsonbSet<Member: QueryBindable>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, QueryValue>, JSONPath<_JSONPathCase, Member>>,
    _ value: some QueryExpression<Member>
  ) -> _JSONSetExpression<QueryValue> {
    appending(.jsonSetArguments("jsonb_object", path, .jsonEncoded(value)))
  }
}

public enum _JSONPathRoot {}
public enum _JSONPathMember {}
public enum _JSONPathElement {}
public enum _JSONPathCase {}

public protocol _JSONPathContext {
  associatedtype _Member = _JSONPathMember
  associatedtype _Element = _JSONPathElement
  associatedtype _Case = _JSONPathCase
}

extension _JSONPathRoot: _JSONPathContext {}
extension _JSONPathMember: _JSONPathContext {}
extension _JSONPathElement: _JSONPathContext {}

extension _JSONPathCase: _JSONPathContext {
  public typealias _Member = _JSONPathMember?
  public typealias _Element = _JSONPathElement?
  public typealias _Case = _JSONPathCase?
}

extension Optional: _JSONPathContext {
  public typealias _Member = _JSONPathMember?
  public typealias _Element = _JSONPathElement?
  public typealias _Case = _JSONPathCase?
}

public protocol _OptionalJSONPathContext {}
extension Optional: _OptionalJSONPathContext {}
extension _JSONPathCase: _OptionalJSONPathContext {}

public protocol _RequiredJSONPathContext {}
extension _JSONPathRoot: _RequiredJSONPathContext {}
extension _JSONPathMember: _RequiredJSONPathContext {}
extension _JSONPathElement: _RequiredJSONPathContext {}

public protocol _JSONPathMemberContext {}
extension _JSONPathMember: _JSONPathMemberContext {}
extension _JSONPathCase: _JSONPathMemberContext {}
extension Optional: _JSONPathMemberContext where Wrapped == _JSONPathMember {}

public protocol _JSONPathElementContext {}
extension _JSONPathElement: _JSONPathElementContext {}
extension Optional: _JSONPathElementContext where Wrapped == _JSONPathElement {}

public protocol _JSONObjectRepresentation<_Object> {
  associatedtype _Object: Table
}

public protocol _AnyJSONRepresentable: QueryRepresentable where QueryOutput: Codable {}

public protocol _JSONRepresentable: _AnyJSONRepresentable {}
extension JSONRepresentation: _JSONRepresentable {}

public protocol _JSONBRepresentable: _AnyJSONRepresentable {}

extension JSONBRepresentation: _JSONBRepresentable {}

extension JSONRepresentation: _JSONObjectRepresentation where QueryOutput: Table {
  public typealias _Object = QueryOutput
}

extension JSONBRepresentation: _JSONObjectRepresentation where QueryOutput: Table {
  public typealias _Object = QueryOutput
}

public protocol _JSONArrayRepresentation<_Element, _ElementRepresentation> {
  associatedtype _Element: Codable
  associatedtype _ElementRepresentation: QueryRepresentable
}

public protocol _JSONDictionaryRepresentation<_Key, _Value> {
  associatedtype _Key: QueryRepresentable
  associatedtype _Value: Codable
  associatedtype _ValueRepresentation: QueryRepresentable
}

public protocol _DictionaryProtocol<Key, Value> {
  associatedtype Key: Hashable
  associatedtype Value
}

extension Dictionary: _DictionaryProtocol {}

extension JSONRepresentation: _JSONArrayRepresentation
where QueryOutput: RangeReplaceableCollection, QueryOutput.Element: Codable {
  public typealias _Element = QueryOutput.Element
  public typealias _ElementRepresentation = JSONRepresentation<QueryOutput.Element>
}

extension JSONBRepresentation: _JSONArrayRepresentation
where QueryOutput: RangeReplaceableCollection, QueryOutput.Element: Codable {
  public typealias _Element = QueryOutput.Element
  public typealias _ElementRepresentation = JSONBRepresentation<QueryOutput.Element>
}

extension JSONRepresentation: _JSONDictionaryRepresentation
where QueryOutput: _DictionaryProtocol, QueryOutput.Key == String, QueryOutput.Value: Codable {
  public typealias _Key = String
  public typealias _Value = QueryOutput.Value
  public typealias _ValueRepresentation = JSONRepresentation<QueryOutput.Value>
}

extension JSONBRepresentation: _JSONDictionaryRepresentation
where QueryOutput: _DictionaryProtocol, QueryOutput.Key == String, QueryOutput.Value: Codable {
  public typealias _Key = String
  public typealias _Value = QueryOutput.Value
  public typealias _ValueRepresentation = JSONBRepresentation<QueryOutput.Value>
}

extension ISO_9075.Fragment {
  fileprivate static func jsonEncoded<V: QueryRepresentable>(
    _ value: some QueryExpression<V>
  ) -> ISO_9075.Fragment {
    V._queryFragment(jsonEncoding: value.argumentFragment)
  }

  fileprivate static func jsonSetArguments<Root, Context, Member>(
    _ objectFunction: ISO_9075.Fragment,
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>,
    _ value: ISO_9075.Fragment
  ) -> ISO_9075.Fragment {
    let path = JSONPath()[keyPath: path]
    guard let caseName = path.caseName
    else {
      return "\(text: path.pathString), \(value)"
    }
    return """
      \(text: "$" + path.components.dropLast().joined()), \
      \(objectFunction)(\(text: caseName), \(value))
      """
  }

  fileprivate static func jsonArguments<Root, Context, Member>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>,
    appending suffix: String = ""
  ) -> ISO_9075.Fragment {
    "\(text: JSONPath()[keyPath: path].pathString + suffix)"
  }

  fileprivate static func jsonArguments<Root, Context, Member>(
    _ path: KeyPath<JSONPath<_JSONPathRoot, Root>, JSONPath<Context, Member>>,
    appending suffix: String = "",
    _ value: ISO_9075.Fragment
  ) -> ISO_9075.Fragment {
    "\(jsonArguments(path, appending: suffix)), \(value)"
  }
}

extension String {
  fileprivate static func member(_ name: String) -> String {
    let escaped =
      name
      .replacing("\\", with: "\\\\")
      .replacing("\"", with: "\\\"")
    return ".\"\(escaped)\""
  }

  fileprivate static func index(_ index: Int) -> String {
    index < 0 ? "[#\(index)]" : "[\(index)]"
  }
}
