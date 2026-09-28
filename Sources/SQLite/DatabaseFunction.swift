public import ISO_9075_Foundation
public import Foundation
public import SQL

public protocol DatabaseFunction<Input, Output> {
  associatedtype Input

  associatedtype Output

  var name: String { get }

  var argumentCount: Int? { get }

  var isDeterministic: Bool { get }
}

public protocol ScalarDatabaseFunction<Input, Output>: DatabaseFunction {
  func invoke(_ decoder: inout some QueryDecoder) throws -> ISO_9075.Value
}

extension ScalarDatabaseFunction {
  @_disfavoredOverload
  public func callAsFunction<each T: QueryExpression>(
    _ input: repeat each T
  ) -> some QueryExpression<Output>
  where Input == (repeat (each T).QueryValue) {
    $_isSelecting.withValue(false) {
      SQLQueryExpression(
        "\(quote: name)(\(Array(repeat each input).joined(separator: ", ")))"
      )
    }
  }
}

public protocol AggregateDatabaseFunction<Input, Output>: DatabaseFunction {
  associatedtype Element = Input

  func step(_ decoder: inout some QueryDecoder) throws -> Element

  func invoke(_ arguments: some Sequence<Element>) throws -> ISO_9075.Value
}

extension AggregateDatabaseFunction {
  @_disfavoredOverload
  public func callAsFunction(
    _ input: some QueryExpression<Input>,
    distinct isDistinct: Bool = false,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<Output>
  where Input: QueryBindable {
    $_isSelecting.withValue(false) {
      AggregateFunctionExpression<Output>(name, distinct: isDistinct, input, filter: filter)
    }
  }

  #if !SuppressPlatformSQLiteAvailability
    @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
  #endif
  @_disfavoredOverload
  public func callAsFunction(
    _ input: some QueryExpression<Input>,
    distinct isDistinct: Bool = false,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<Output>
  where Input: QueryBindable {
    $_isSelecting.withValue(false) {
      AggregateFunctionExpression<Output>(
        name, distinct: isDistinct, input, order: order, filter: filter
      )
    }
  }

  @_disfavoredOverload
  public func callAsFunction<each T: QueryExpression>(
    _ input: repeat each T,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<Output>
  where Input == (repeat (each T).QueryValue) {
    $_isSelecting.withValue(false) {
      AggregateFunctionExpression<Output>(name, repeat each input, filter: filter)
    }
  }

  #if !SuppressPlatformSQLiteAvailability
    @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
  #endif
  @_disfavoredOverload
  public func callAsFunction<each T: QueryExpression>(
    _ input: repeat each T,
    order: some QueryExpression,
    filter: (some QueryExpression<Bool>)? = Bool?.none
  ) -> some QueryExpression<Output>
  where Input == (repeat (each T).QueryValue) {
    $_isSelecting.withValue(false) {
      AggregateFunctionExpression<Output>(name, repeat each input, order: order, filter: filter)
    }
  }
}

// NB: Provides better error diagnostics for '@DatabaseFunction' macro-generated code.
//
//     - Type 'CKShare' has no member '_columnWidth'
//     + Global function '_columnWidth' requires that 'CKShare' conform to 'QueryExpression'
@_transparent
public func _columnWidth<T: QueryExpression>(_: T.Type) -> Int {
  T._columnWidth
}

// NB: Provides better error diagnostics for '@DatabaseFunction' macro-generated code.
//
//     - No exact matches in call to instance method 'decode'
//     + Global function '_requireQueryRepresentable' requires that 'CKShare' conform to 'QueryRepresentable'
@_transparent
public func _requireQueryRepresentable<T: QueryRepresentable>(_: T.Type) -> T.Type {
  T.self
}

public struct _DatabaseFunctionDeallocated: LocalizedError, Sendable {
  let message: String
  public init(_ message: String) {
    self.message = message
  }
  public var errorDescription: String? {
    message
  }
}
