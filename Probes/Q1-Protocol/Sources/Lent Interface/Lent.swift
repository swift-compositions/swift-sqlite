public import ISO_9075_Call_Level_Interface

/// The new shape, beside the one swift-iso-9075 has today.
public enum Lent {}

extension Lent {
    /// `ISO_9075.Connection`, for a conformer that is neither copyable nor escapable.
    public protocol Connection: ~Copyable, ~Escapable {
        associatedtype Dialect: ISO.`9075`.Dialect
        associatedtype Row: ISO.`9075`.Row

        var dialect: Dialect { get }

        func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int

        func fetchAll<Value>(
            _ statement: ISO.`9075`.Rendering,
            decode: (Row) throws(ISO.`9075`.Error) -> Value
        ) throws(ISO.`9075`.Error) -> [Value]
    }

    public protocol Reader: Sendable {
        associatedtype Connection: Lent.Connection & ~Copyable & ~Escapable

        @_disfavoredOverload
        nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value
    }

    public protocol Database: Reader {
        @_disfavoredOverload
        nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value

        @_disfavoredOverload
        nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value
    }
}

// The fragment overloads of today's `ISO_9075.Connection`, on a conformer that is not copyable and not escapable.
extension Lent.Connection where Self: ~Copyable, Self: ~Escapable {
    public func execute(_ fragment: ISO.`9075`.Fragment) throws(ISO.`9075`.Error) -> Int {
        try execute(rendering(fragment))
    }

    public func fetchAll<Value>(
        _ fragment: ISO.`9075`.Fragment,
        decode: (Row) throws(ISO.`9075`.Error) -> Value
    ) throws(ISO.`9075`.Error) -> [Value] {
        try fetchAll(rendering(fragment), decode: decode)
    }

    public func fetchOne<Value>(
        _ fragment: ISO.`9075`.Fragment,
        decode: (Row) throws(ISO.`9075`.Error) -> Value
    ) throws(ISO.`9075`.Error) -> Value? {
        try fetchAll(fragment, decode: decode).first
    }

    private func rendering(_ fragment: ISO.`9075`.Fragment) throws(ISO.`9075`.Error) -> ISO.`9075`.Rendering {
        do throws(ISO.`9075`.Value.Failure) {
            return try dialect.render(fragment)
        } catch {
            throw .binding(error)
        }
    }
}

// The overloads of today's `ISO_9075.Database` that flatten `Failure<ISO_9075.Error>` to `ISO_9075.Error`.
extension Lent.Reader {
    public nonisolated(nonsending) func read<Value>(
        _ body: sending (borrowing Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await reading(self, body)
        } catch {
            throw error.error
        }
    }
}

extension Lent.Database {
    public nonisolated(nonsending) func write<Value>(
        _ body: sending (borrowing Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await writing(self, body)
        } catch {
            throw error.error
        }
    }

    public nonisolated(nonsending) func execute(
        _ fragment: ISO.`9075`.Fragment
    ) async throws(ISO.`9075`.Error) -> Int {
        try await write { connection throws(ISO.`9075`.Error) in try connection.execute(fragment) }
    }
}

private nonisolated(nonsending) func reading<Reader: Lent.Reader, Value, Thrown: Swift.Error>(
    _ reader: Reader,
    _ body: sending (borrowing Reader.Connection) throws(Thrown) -> sending Value
) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
    try await reader.read(body)
}

private nonisolated(nonsending) func writing<Database: Lent.Database, Value, Thrown: Swift.Error>(
    _ database: Database,
    _ body: sending (borrowing Database.Connection) throws(Thrown) -> sending Value
) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
    try await database.write(body)
}
