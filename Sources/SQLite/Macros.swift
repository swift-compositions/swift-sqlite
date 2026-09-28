public import SQL

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseCollation(_ name: String = "") =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "DatabaseCollationMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction(
  _ name: String = "",
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression, R: QueryBindable>(
  _ name: String = "",
  as representableFunctionType: ((repeat each T) -> R).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression>(
  _ name: String = "",
  as representableFunctionType: ((repeat each T) -> Void).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression, R: QueryBindable>(
  _ name: String = "",
  as representableFunctionType: ((any Sequence<(repeat each T)>) -> R).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<each T: QueryRepresentable & QueryExpression>(
  _ name: String = "",
  as representableFunctionType: ((any Sequence<(repeat each T)>) -> Void).Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "DatabaseFunctionMacro"
  )

@attached(peer, names: overloaded, prefixed(`$`))
public macro DatabaseFunction<R: QueryBindable>(
  _ name: String = "",
  as representableType: R.Type,
  isDeterministic: Bool = false
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "DatabaseFunctionMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro SQLiteIsolationCheck<each Input, Output>(
  collation: (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "IsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro SQLiteIsolationCheck<each Input, Output>(
  collation: @MainActor (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "MainActorIsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro SQLiteIsolationCheck<each Input, Output>(
  function: (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "IsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro SQLiteIsolationCheck<each Input, Output>(
  function: @MainActor (repeat each Input) throws -> Output
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "MainActorIsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro SQLiteIsolationCheck(
  property: () -> Void
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "IsolationCheckMacro"
  )

@_documentation(visibility: private)
@freestanding(declaration)
public macro SQLiteIsolationCheck(
  property: @MainActor () -> Void
) =
  #externalMacro(
    module: "SQLite_Macros_Implementation",
    type: "MainActorIsolationCheckMacro"
  )
