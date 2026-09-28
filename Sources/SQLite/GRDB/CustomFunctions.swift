#if GRDB
public import GRDB
import GRDBSQLite
import ISO_9075_Foundation
public import SQL

extension GRDB.Database {
  public func add(function: some ScalarDatabaseFunction) {
    sqlite3_create_function_v2(
      sqliteConnection,
      function.name,
      function.argumentCount,
      function.textEncoding,
      Unmanaged.passRetained(ScalarDatabaseFunctionDefinition(function)).toOpaque(),
      { context, argumentCount, arguments in
        do {
          let definition = Unmanaged<ScalarDatabaseFunctionDefinition>
            .fromOpaque(sqlite3_user_data(context))
            .takeUnretainedValue()
          definition.decoder.reset(argumentCount: argumentCount, arguments: arguments)
          try definition.function
            .invoke(&definition.decoder)
            .result(db: context)
        } catch {
          ISO_9075.Value.invalid(ISO_9075.Value.Failure(error)).result(db: context)
        }
      },
      nil,
      nil,
      { context in
        guard let context else { return }
        Unmanaged<ScalarDatabaseFunctionDefinition>.fromOpaque(context).release()
      }
    )
  }

  public func add(function: some AggregateDatabaseFunction) {
    let body = Unmanaged.passRetained(AggregateDatabaseFunctionDefinition(function)).toOpaque()
    sqlite3_create_function_v2(
      sqliteConnection,
      function.name,
      function.argumentCount,
      function.textEncoding,
      body,
      nil,
      { context, argumentCount, arguments in
        let function = AggregateDatabaseFunctionContext[context].takeUnretainedValue()
        function.decoder.reset(argumentCount: argumentCount, arguments: arguments)
        do {
          try function.iterator.step(&function.decoder)
        } catch {
          sqlite3_result_error(context, "\(error)", -1)
        }
      },
      { context in
        let unmanagedFunction = AggregateDatabaseFunctionContext[context]
        let function = unmanagedFunction.takeUnretainedValue()
        unmanagedFunction.release()
        function.iterator.result.result(db: context)
      },
      { context in
        guard let context else { return }
        Unmanaged<AggregateDatabaseFunctionContext>.fromOpaque(context).release()
      }
    )
  }

  public func remove(function: some DatabaseFunction) {
    sqlite3_create_function_v2(
      sqliteConnection,
      function.name,
      function.argumentCount,
      function.textEncoding,
      nil,
      nil,
      nil,
      nil,
      nil
    )
  }
}

extension DatabaseFunction {
  fileprivate var argumentCount: Int32 {
    Int32(argumentCount ?? -1)
  }

  fileprivate var textEncoding: Int32 {
    SQLITE_UTF8 | (isDeterministic ? SQLITE_DETERMINISTIC : 0)
  }
}

private final class ScalarDatabaseFunctionDefinition {
  let function: any ScalarDatabaseFunction
  var decoder: SQLiteFunctionDecoder
  init(_ function: some ScalarDatabaseFunction) {
    self.function = function
    self.decoder = SQLiteFunctionDecoder(name: function.name)
  }
}

private final class AggregateDatabaseFunctionDefinition {
  let function: any AggregateDatabaseFunction
  init(_ function: some AggregateDatabaseFunction) {
    self.function = function
  }
}

private final class AggregateDatabaseFunctionContext {
  static subscript(context: OpaquePointer?) -> Unmanaged<AggregateDatabaseFunctionContext> {
    let size = MemoryLayout<Unmanaged<AggregateDatabaseFunctionContext>>.size
    let pointer = sqlite3_aggregate_context(context, Int32(size))!
    if pointer.load(as: Int.self) == 0 {
      let definition = Unmanaged<AggregateDatabaseFunctionDefinition>
        .fromOpaque(sqlite3_user_data(context))
        .takeUnretainedValue()
      let context = AggregateDatabaseFunctionContext(definition.function)
      let unmanagedContext = Unmanaged.passRetained(context)
      pointer
        .assumingMemoryBound(to: Unmanaged<AggregateDatabaseFunctionContext>.self)
        .pointee = unmanagedContext
      return unmanagedContext
    } else {
      return
        pointer
        .assumingMemoryBound(to: Unmanaged<AggregateDatabaseFunctionContext>.self)
        .pointee
    }
  }
  let iterator: any AggregateDatabaseFunctionIteratorProtocol
  var decoder: SQLiteFunctionDecoder
  init(_ body: some AggregateDatabaseFunction) {
    self.iterator = AggregateDatabaseFunctionIterator(body)
    self.decoder = SQLiteFunctionDecoder(name: body.name)
  }
}

private protocol AggregateDatabaseFunctionIteratorProtocol<Body> {
  associatedtype Body: AggregateDatabaseFunction

  var body: Body { get }
  func step(_ decoder: inout some QueryDecoder) throws
  var result: ISO_9075.Value { get }
}

private final class AggregateDatabaseFunctionIterator<
  Body: AggregateDatabaseFunction
>: AggregateDatabaseFunctionIteratorProtocol {
  let body: Body
  var elements: [Body.Element] = []
  init(_ body: Body) {
    self.body = body
  }
  func step(_ decoder: inout some QueryDecoder) throws {
    elements.append(try body.step(&decoder))
  }
  var result: ISO_9075.Value {
    do {
      return try body.invoke(elements)
    } catch {
      return .invalid(ISO_9075.Value.Failure(error))
    }
  }
}

extension ISO_9075.Value {
  fileprivate func result(db: OpaquePointer?) {
    switch self {
    case .null:
      sqlite3_result_null(db)
    case .bool(let bool):
      sqlite3_result_int64(db, bool ? 1 : 0)
    case .int(let int):
      sqlite3_result_int64(db, int)
    case .double(let double):
      sqlite3_result_double(db, double)
    case .text(let text), .decimal(let text):
      text.result(db: db)
    case .timestamp(let instant):
      do {
        try ISO_9075.Literal.timestamp(instant).result(db: db)
      } catch {
        sqlite3_result_error(db, error.description, -1)
      }
    case .uuid(let uuid):
      String(uuid).lowercased().result(db: db)
    case .json(let bytes):
      String(decoding: bytes.map(\.underlying), as: UTF8.self).result(db: db)
    case .blob(let blob) where blob.isEmpty:
      sqlite3_result_zeroblob(db, 0)
    case .blob(let blob):
      blob.map(\.underlying).withUnsafeBytes {
        sqlite3_result_blob(db, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
      }
    case .array:
      sqlite3_result_error(db, "SQLite has no array values", -1)
    case .invalid(let failure):
      sqlite3_result_error(db, failure.description, -1)
    }
  }
}

extension String {
  fileprivate func result(db: OpaquePointer?) {
    var text = self
    text.withUTF8 { utf8 in
      utf8.withMemoryRebound(to: CChar.self) {
        sqlite3_result_text(db, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
      }
    }
  }
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

#endif
