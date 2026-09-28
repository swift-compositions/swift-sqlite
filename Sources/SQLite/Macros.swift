public import SQL

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseCollation(_ name: String = "") =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "DatabaseCollationMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction(
  _ name: String = "",
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression, R: QueryBindable>(
  _ name: String = "",
  as representableFunctionType: ((repeat each T) -> R).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression>(
  _ name: String = "",
  as representableFunctionType: ((repeat each T) -> Void).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression, R: QueryBindable>(
  _ name: String = "",
  as representableFunctionType: ((any Sequence<(repeat each T)>) -> R).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression>(
  _ name: String = "",
  as representableFunctionType: ((any Sequence<(repeat each T)>) -> Void).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<R: QueryBindable>(
  _ name: String = "",
  as representableType: R.Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "DatabaseFunctionMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro StructuredQueriesIsolationCheck<each Input, Output>(
  collation: (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "IsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro StructuredQueriesIsolationCheck<each Input, Output>(
  collation: @MainActor (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "MainActorIsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro StructuredQueriesIsolationCheck<each Input, Output>(
  function: (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "IsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro StructuredQueriesIsolationCheck<each Input, Output>(
  function: @MainActor (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "MainActorIsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro StructuredQueriesIsolationCheck(
  property: () -> Void
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "IsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro StructuredQueriesIsolationCheck(
  property: @MainActor () -> Void
) =
  #externalMacro(
    module: "StructuredQueriesSQLiteMacros",
    type: "MainActorIsolationCheckMacro"
  )
