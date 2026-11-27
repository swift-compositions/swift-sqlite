public import ISO_9075_Call_Level_Interface
public import Lent_Interface
public import SQLite_Handle
internal import Synchronization

extension SQLite {
    /// A writer and readers, each an actor on a thread of its own. Sendable, with nothing unchecked.
    public struct Database: Lent.Database, Sendable {
        public typealias Connection = SQLite.Handle

        public let writer: SQLite.Worker
        public let readers: [SQLite.Worker]
        let next: Turn

        public init(path: Swift.String, readers count: Int = 2) async throws(ISO.`9075`.Error) {
            self.writer = try SQLite.Worker(path: path)
            var readers: [SQLite.Worker] = []
            for _ in 0..<count { readers.append(try SQLite.Worker(path: path)) }
            self.readers = readers
            self.next = Turn()
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing SQLite.Handle) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await readers[next.take() % readers.count].run(begin: "BEGIN", end: "COMMIT", body)
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing SQLite.Handle) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await writer.run(begin: "BEGIN IMMEDIATE", end: "COMMIT", body)
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing SQLite.Handle) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await writer.run(begin: "BEGIN IMMEDIATE", end: "ROLLBACK", body)
        }
    }

    final class Turn: Sendable {
        let count = Atomic<Int>(0)
        func take() -> Int { count.add(1, ordering: .relaxed).oldValue }
    }
}
