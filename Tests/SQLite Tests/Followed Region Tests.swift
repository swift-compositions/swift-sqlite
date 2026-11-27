import ISO_9075_Call_Level_Interface
import SQLite
import SQLite_Test_Support
import Synchronization
import Testing

/// How often a followed read's body ran.
private final class Runs: Sendable {
    private let count = Atomic<Int>(0)

    func add() { count.add(1, ordering: .relaxed) }

    var value: Int { count.load(ordering: .relaxed) }
}

/// What a listener has handled, on the actor that listens.
@MainActor
private final class Seen {
    var values: [Int] = []
    var last: Int { values.last ?? -1 }
}

private func library() async throws -> SQLite.Database {
    let database = try SQLite.Database()
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(
            script: """
                CREATE TABLE author (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
                CREATE TABLE book (
                    id INTEGER PRIMARY KEY,
                    author INTEGER NOT NULL REFERENCES author (id) ON DELETE CASCADE,
                    title TEXT NOT NULL
                );
                CREATE VIEW title AS SELECT title FROM book;
                CREATE TABLE note (id INTEGER PRIMARY KEY, text TEXT NOT NULL);
                CREATE TABLE audit (id INTEGER PRIMARY KEY, what TEXT NOT NULL);
                CREATE TRIGGER note_audit AFTER INSERT ON note BEGIN INSERT INTO audit (what) VALUES ('note'); END;
                INSERT INTO author VALUES (1, 'A');
                INSERT INTO book VALUES (1, 1, 'T');
                """
        )
    }
    return database
}

/// A listener on the main actor that follows the number of rows of `table`. Returns when it has its first answer.
@MainActor
private func follow(
    _ table: String,
    in database: SQLite.Database,
    counting runs: Runs,
    into seen: Seen
) async throws -> Task<Void, any Error> {
    let answers = try await database.observe { connection throws(ISO.`9075`.Error) -> Int in
        runs.add()
        return try Int.fetchOne(connection, sql: "SELECT count(*) FROM \(table)") ?? -1
    }
    let (started, signal) = AsyncStream<Void>.makeStream()
    let listening = Task { @MainActor in
        for try await answer in answers {
            seen.values.append(answer)
            signal.yield()
        }
    }
    for await _ in started { break }
    return listening
}

private func write(_ database: SQLite.Database, _ script: String) async throws {
    try await database.write { connection throws(ISO.`9075`.Error) in try connection.execute(script: script) }
}

@Suite struct `Followed Region Tests` {
    @Test @MainActor func `a write to another table does not read a followed read again`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("book", in: database, counting: runs, into: seen)
        for number in 1...3 {
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO note (text) VALUES (?)", arguments: ["\(number)"])
            }
        }
        #expect(runs.value == 1)
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO book (author, title) VALUES (1, 'U')")
        }
        #expect(runs.value == 2)
        #expect(seen.values == [1, 2])
        listening.cancel()
    }

    @Test @MainActor func `a write that writes nothing reads no followed read again`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("book", in: database, counting: runs, into: seen)
        let count = try await database.write { connection throws(ISO.`9075`.Error) in
            try Int.fetchOne(connection, sql: "SELECT count(*) FROM book")
        }
        #expect(count == 1)
        #expect(runs.value == 1)
        listening.cancel()
    }

    @Test @MainActor func `a row that a foreign key action removes reaches the followed read of its table`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("book", in: database, counting: runs, into: seen)
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "DELETE FROM author WHERE id = 1")
        }
        #expect(seen.values == [1, 0])
        listening.cancel()
    }

    @Test @MainActor func `a row that a trigger adds reaches the followed read of its table`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("audit", in: database, counting: runs, into: seen)
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO note (text) VALUES ('a')")
        }
        #expect(seen.values == [0, 1])
        listening.cancel()
    }

    @Test @MainActor func `a write by a script reaches the followed read of its table`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("note", in: database, counting: runs, into: seen)
        try await write(database, "INSERT INTO note (text) VALUES ('a'); INSERT INTO note (text) VALUES ('b')")
        #expect(seen.values == [0, 2])
        listening.cancel()
    }

    @Test @MainActor func `a write to a view's table reaches the followed read of the view`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("title", in: database, counting: runs, into: seen)
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO book (author, title) VALUES (1, 'U')")
        }
        #expect(seen.values == [1, 2])
        listening.cancel()
    }

    @Test @MainActor func `a change of the schema reads every followed read again`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("book", in: database, counting: runs, into: seen)
        try await write(database, "CREATE TABLE extra (id INTEGER PRIMARY KEY)")
        #expect(runs.value == 2)
        #expect(seen.values == [1])
        listening.cancel()
    }

    @Test @MainActor func `a savepoint that is rolled back and a later write in one scope reach the followed read`() async throws {
        let database = try await library()
        let (runs, seen) = (Runs(), Seen())
        let listening = try await follow("note", in: database, counting: runs, into: seen)
        try await database.write { connection throws(ISO.`9075`.Error) in
            do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
                try connection.savepoint { () throws(ISO.`9075`.Error) in
                    try connection.execute(sql: "INSERT INTO book (author, title) VALUES (1, 'U')")
                    return .rollback
                }
            } catch {
                throw error.error
            }
            try connection.execute(sql: "INSERT INTO note (text) VALUES ('a')")
        }
        #expect(seen.values == [0, 1])
        listening.cancel()
    }
}
