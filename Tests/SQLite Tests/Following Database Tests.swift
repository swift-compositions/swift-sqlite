import ISO_9075_Call_Level_Interface
import SQL
import SQL_Macros
import SQLite
import Testing

// SQLite's database through `FollowingDatabase` alone, as a store written for any engine that follows a read sees it.

/// What a listener has handled, on the actor that listens.
@MainActor
private final class Handled {
    var values: [Int] = []
}

private func prepare<Database: FollowingDatabase>(_ database: Database) async throws {
    _ = try await database.execute("CREATE TABLE counter (id INTEGER PRIMARY KEY, value INTEGER NOT NULL)")
    _ = try await database.execute("INSERT INTO counter VALUES (1, 0)")
    _ = try await database.execute("CREATE TABLE other (id INTEGER PRIMARY KEY)")
}

private func value<Connection: ISO.`9075`.Connection & ~Copyable & ~Escapable>(
    _ connection: borrowing Connection
) throws(ISO.`9075`.Error) -> Int {
    try #sql("SELECT value FROM counter WHERE id = 1", as: Int.self).fetch.one(connection) ?? -1
}

@MainActor
private func follow<Database: FollowingDatabase>(
    _ database: Database
) async throws -> FollowedRead<Int> {
    try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
}

@MainActor
@Suite(.timeLimit(.minutes(1))) struct `Following Database Tests` {
    @Test(arguments: [true, false])
    func `the first element is the answer when the read was followed`(file: Bool) async throws {
        let database = try file ? SQLite.Database(path: Scratch.path()) : SQLite.Database()
        try await prepare(database)
        _ = try await database.execute("UPDATE counter SET value = 7")
        var answers = try await follow(database).makeAsyncIterator()
        #expect(try await answers.next() == 7)
    }

    @Test(arguments: [true, false])
    func `when a write returns, the listener has handled its answer`(file: Bool) async throws {
        let database = try file ? SQLite.Database(path: Scratch.path()) : SQLite.Database()
        try await prepare(database)
        let handled = Handled()
        let answers = try await follow(database)
        let (first, signal) = AsyncStream<Void>.makeStream()
        let listening = Task {
            for try await answer in answers {
                handled.values.append(answer)
                signal.yield()
            }
        }
        // The listener has taken its first answer before the first write.
        for await _ in first { break }
        for number in 1...200 {
            _ = try await database.execute("UPDATE counter SET value = \(number)")
            #expect(handled.values.last == number)
        }
        listening.cancel()
        #expect(handled.values == Array(0...200))
    }

    @Test func `a commit that leaves the answer equal yields nothing`() async throws {
        let database = try SQLite.Database()
        try await prepare(database)
        var answers = try await follow(database).makeAsyncIterator()
        #expect(try await answers.next() == 0)
        _ = try await database.execute("INSERT INTO other VALUES (1)")
        _ = try await database.execute("UPDATE counter SET value = 3")
        #expect(try await answers.next() == 3)
    }

    @Test func `a failing first read is thrown`() async throws {
        let database = try SQLite.Database()
        await #expect(throws: ISO.`9075`.Error.self) { _ = try await follow(database) }
    }
}
