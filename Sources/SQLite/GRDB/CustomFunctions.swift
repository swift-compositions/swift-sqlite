#if GRDB
    internal import Byte
    package import GRDB
    import GRDBSQLite
    import ISO_9075_Foundation
    import SQL
    internal import RFC_4122

    extension SQLite.Connection {
        /// Adds `function` to this connection, for every statement it executes after. Call it from
        /// ``SQLite/Configuration/prepareDatabase(_:)`` to have it on every connection.
        public func add(function: some ScalarDatabaseFunction) {
            database.add(function: function)
        }

        public func add(function: some AggregateDatabaseFunction) {
            database.add(function: function)
        }

        public func remove(function: some DatabaseFunction) {
            database.remove(function: function)
        }
    }

    extension GRDB.Database {
        package func add(function: some ScalarDatabaseFunction) {
            unsafe sqlite3_create_function_v2(
                sqliteConnection,
                function.name,
                function.argumentCount,
                function.textEncoding,
                Unmanaged.passRetained(ScalarDatabaseFunctionDefinition(function)).toOpaque(),
                { context, argumentCount, arguments in
                    do {
                        let definition = unsafe Unmanaged<ScalarDatabaseFunctionDefinition>
                            .fromOpaque(sqlite3_user_data(context))
                            .takeUnretainedValue()
                        unsafe definition.decoder.reset(argumentCount: argumentCount, arguments: arguments)
                        unsafe try definition.function
                            .invoke(&definition.decoder)
                            .result(db: context)
                    } catch {
                        unsafe ISO_9075.Value.invalid(ISO_9075.Value.Failure(error)).result(db: context)
                    }
                },
                nil,
                nil,
                { context in
                    guard let context = unsafe context else { return }
                    unsafe Unmanaged<ScalarDatabaseFunctionDefinition>.fromOpaque(context).release()
                }
            )
        }

        package func add(function: some AggregateDatabaseFunction) {
            let body = unsafe Unmanaged.passRetained(AggregateDatabaseFunctionDefinition(function)).toOpaque()
            unsafe sqlite3_create_function_v2(
                sqliteConnection,
                function.name,
                function.argumentCount,
                function.textEncoding,
                body,
                nil,
                { context, argumentCount, arguments in
                    guard let unmanagedFunction = unsafe AggregateDatabaseFunctionContext[context] else {
                        unsafe sqlite3_result_error_nomem(context)
                        return
                    }
                    let function = unsafe unmanagedFunction.takeUnretainedValue()
                    unsafe function.decoder.reset(argumentCount: argumentCount, arguments: arguments)
                    do {
                        try function.iterator.step(&function.decoder)
                    } catch {
                        unsafe sqlite3_result_error(context, "\(error)", -1)
                    }
                },
                { context in
                    guard let unmanagedFunction = unsafe AggregateDatabaseFunctionContext[context] else {
                        unsafe sqlite3_result_error_nomem(context)
                        return
                    }
                    let function = unsafe unmanagedFunction.takeUnretainedValue()
                    unsafe unmanagedFunction.release()
                    unsafe function.iterator.result.result(db: context)
                },
                { context in
                    guard let context = unsafe context else { return }
                    unsafe Unmanaged<AggregateDatabaseFunctionContext>.fromOpaque(context).release()
                }
            )
        }

        package func remove(function: some DatabaseFunction) {
            unsafe sqlite3_create_function_v2(
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
        static subscript(context: OpaquePointer?) -> Unmanaged<AggregateDatabaseFunctionContext>? {
            let size = unsafe MemoryLayout<Unmanaged<AggregateDatabaseFunctionContext>>.size
            guard let pointer = unsafe sqlite3_aggregate_context(context, Int32(size)) else { return nil }
            guard unsafe pointer.load(as: Int.self) == 0 else {
                return
                    unsafe pointer
                    .assumingMemoryBound(to: Unmanaged<AggregateDatabaseFunctionContext>.self)
                    .pointee
            }
            let definition = unsafe Unmanaged<AggregateDatabaseFunctionDefinition>
                .fromOpaque(sqlite3_user_data(context))
                .takeUnretainedValue()
            let context = AggregateDatabaseFunctionContext(definition.function)
            let unmanagedContext = unsafe Unmanaged.passRetained(context)
            unsafe pointer
                .assumingMemoryBound(to: Unmanaged<AggregateDatabaseFunctionContext>.self)
                .pointee = unsafe unmanagedContext
            return unsafe unmanagedContext
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
                unsafe sqlite3_result_null(db)
            case .bool(let bool):
                unsafe sqlite3_result_int64(db, bool ? 1 : 0)
            case .int(let int):
                unsafe sqlite3_result_int64(db, int)
            case .double(let double):
                unsafe sqlite3_result_double(db, double)
            case .text(let text), .decimal(let text):
                unsafe text.result(db: db)
            case .timestamp(let instant):
                do {
                    unsafe try ISO_9075.Literal.timestamp(instant).result(db: db)
                } catch {
                    unsafe sqlite3_result_error(db, error.description, -1)
                }
            case .uuid(let uuid):
                unsafe String(uuid).lowercased().result(db: db)
            case .json(let bytes):
                unsafe bytes.withUnsafeBytes { unsafe String(decoding: $0, as: UTF8.self) }.result(db: db)
            case .blob(let blob) where blob.isEmpty:
                unsafe sqlite3_result_zeroblob(db, 0)
            case .blob(let blob):
                blob.withUnsafeBytes {
                    unsafe sqlite3_result_blob(db, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
                }
            case .array:
                unsafe sqlite3_result_error(db, "SQLite has no array values", -1)
            case .invalid(let failure):
                unsafe sqlite3_result_error(db, failure.description, -1)
            }
        }
    }

    extension String {
        fileprivate func result(db: OpaquePointer?) {
            var text = self
            text.withUTF8 { utf8 in
                unsafe utf8.withMemoryRebound(to: CChar.self) {
                    unsafe sqlite3_result_text(db, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
                }
            }
        }
    }

    let SQLITE_TRANSIENT = unsafe unsafeBitCast(-1, to: sqlite3_destructor_type.self)

#endif
