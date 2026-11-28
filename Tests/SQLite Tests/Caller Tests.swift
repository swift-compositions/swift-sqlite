import Foundation
import ISO_9075_Call_Level_Interface
import Path
import SQL
import SQLite
import SQLite_Test_Support
import Synchronization
import Testing

// What the driver offers its callers beyond the call-level interface (swift-compositions/swift-sqlite#29, #30).

private struct Refused: Swift.Error, Equatable {}

private func items(in database: SQLite.Database) async throws -> SQLite.Database {
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(script: "CREATE TABLE item (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE); CREATE TABLE other (id INTEGER PRIMARY KEY)")
    }
    return database
}

private func names(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> [String] {
    try String.fetchAll(connection, sql: "SELECT name FROM item ORDER BY name")
}

/// A read from code with no asynchronous context.
private func namesNow(_ database: SQLite.Database) throws -> [String] {
    try database.read { connection throws(ISO.`9075`.Error) in try names(connection) }
}

private func add(_ name: String, to database: SQLite.Database) async throws {
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: [name])
    }
}

@Suite struct `Caller Tests` {
    @Suite struct Errors {}
    @Suite struct Opening {}
    @Suite struct Streams {}
    @Suite struct Trace {}
    @Suite struct Files {}
}

extension `Caller Tests`.Errors {
    @Test func `a body that throws any error has it thrown as it threw it`() async throws {
        let database = try await items(in: SQLite.Database())
        await #expect(throws: Refused()) {
            try await database.read { _ in throw Refused() }
        }
        await #expect(throws: Refused()) {
            try await database.write { connection in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
                throw Refused()
            }
        }
        await #expect(throws: Refused()) {
            try await database.withRollback { _ in throw Refused() }
        }
        await #expect(throws: Refused()) {
            try await database.writeWithoutTransaction { _ in throw Refused() }
        }
        #expect(try await database.read { connection in try names(connection) }.isEmpty)
    }

    @Test func `a synchronous read with a body that throws any error has it thrown as it threw it`() throws {
        let database = try SQLite.Database()
        #expect(throws: Refused()) {
            try database.read { _ in throw Refused() }
        }
    }

    @Test func `the database's error under a body that throws any error is the database's error`() async throws {
        let database = try await items(in: SQLite.Database())
        try await add("a", to: database)
        await #expect(throws: ISO.`9075`.Error.self) {
            try await database.write { (connection: borrowing SQLite.Connection) throws in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
            }
        }
    }

    @Test func `a body with a typed error still says whether the body or the database failed`() async throws {
        let database = try SQLite.Database()
        do throws(ISO.`9075`.Failure<Refused>) {
            try await database.write { (_: borrowing SQLite.Connection) throws(Refused) in throw Refused() }
            Issue.record("the write did not throw")
        } catch {
            #expect(error == .body(Refused()))
        }
    }

    /// An enum with two cases that carry a value, typed in the body's literal: the shape that stops the compiler when
    /// such a literal reaches an untyped parameter with a generic result (swift-institute/Issues#209).
    private enum Choice: Swift.Error, Equatable {
        case first(String)
        case second(String)
    }

    @Test func `a body literal typed with an enum error gets the typed overloads`() async throws {
        let database = try SQLite.Database()
        do throws(ISO.`9075`.Failure<Choice>) {
            _ = try await database.read { (_: borrowing SQLite.Connection) throws(Choice) -> Int in throw .first("a") }
            Issue.record("the read did not throw")
        } catch {
            #expect(error == .body(.first("a")))
        }
        do throws(ISO.`9075`.Failure<Choice>) {
            _ = try await database.write { (_: borrowing SQLite.Connection) throws(Choice) -> Int in throw .second("b") }
            Issue.record("the write did not throw")
        } catch {
            #expect(error == .body(.second("b")))
        }
        await #expect(throws: ISO.`9075`.Failure<Choice>.body(.first("c"))) {
            _ = try await database.write { (_: borrowing SQLite.Connection) throws(Choice) -> Int in throw .first("c") }
        }
    }

    @Test func `asynchronous code that reads with the database's error awaits the read`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        try await add("a", to: database)
        // With only the synchronous overload to choose, this `await` is a warning, and warnings are errors here.
        let read = try await database.read { (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
            try names(connection)
        }
        #expect(read == ["a"])
    }
}

extension `Caller Tests`.Opening {
    @Test func `a database that is still opening answers once it is open`() async throws {
        let path = try Scratch.path()
        let opening = SQLite.Database.Opening { () async throws(ISO.`9075`.Error) -> SQLite.Database in
            let database: SQLite.Database
            do throws(SQLite.Error) { database = try SQLite.Database(path: path) } catch { throw ISO.`9075`.Error(error) }
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)")
            }
            return database
        }
        try await opening.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
        }
        #expect(try await opening.read { connection throws(ISO.`9075`.Error) in try names(connection) } == ["a"])
        await #expect(throws: Refused()) { try await opening.write { _ in throw Refused() } }
        var answers = opening.following { connection throws(ISO.`9075`.Error) in try names(connection) }.makeAsyncIterator()
        #expect(try await answers.next() == ["a"])
        try await add("b", to: try await opening.database)
        #expect(try await answers.next() == ["a", "b"])
    }

    @Test func `a database that could not open fails every call with the error of its opening`() async throws {
        let failure = ISO.`9075`.Error.connection("no store")
        let opening = SQLite.Database.Opening { () async throws(ISO.`9075`.Error) -> SQLite.Database in throw failure }
        await #expect(throws: failure) {
            try await opening.read { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in 1 }
        }
        await #expect(throws: failure) { try await opening.write { _ in 1 } }
        await #expect(throws: failure) {
            for try await _ in opening.following({ (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in 1 }) {}
        }
        for await _ in opening.commits() { Issue.record("a commit of a database that never opened") }
    }
}

extension `Caller Tests`.Streams {
    @Test func `a followed stream gives the answer now and after each commit that changes it`() async throws {
        let database = try await items(in: SQLite.Database())
        var answers = database.following { connection throws(ISO.`9075`.Error) in try names(connection) }.makeAsyncIterator()
        #expect(try await answers.next() == [])
        try await add("a", to: database)
        #expect(try await answers.next() == ["a"])
        try await add("b", to: database)
        #expect(try await answers.next() == ["a", "b"])
    }

    @Test func `a followed stream ends with the error its body threw, as it threw it`() async throws {
        let database = try await items(in: SQLite.Database())
        var answers = database.following { connection in
            let read = try names(connection)
            if read.count > 1 { throw Refused() }
            return read
        }.makeAsyncIterator()
        #expect(try await answers.next() == [])
        try await add("a", to: database)
        #expect(try await answers.next() == ["a"])
        try await add("b", to: database)
        await #expect(throws: Refused()) { _ = try await answers.next() }
    }

    @Test func `commits to named tables give one element for each write to them and none for another table`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        var commits = database.commits(to: ["item"]).makeAsyncIterator()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO other DEFAULT VALUES")
        }
        try await database.read { connection throws(ISO.`9075`.Error) in _ = try names(connection) }
        try await add("a", to: database)
        #expect(await commits.next() != nil)
        // The write to `other` gave no element: after the one write to `item` there is none waiting.
        let waiting = Task { () -> Bool in
            var commits = commits
            return await commits.next() != nil
        }
        try await add("b", to: database)
        #expect(await waiting.value)
    }

    @Test func `commits with no table named give an element for a write to any table, and for the schema`() async throws {
        let database = try await items(in: SQLite.Database())
        var commits = database.commits().makeAsyncIterator()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO other DEFAULT VALUES")
        }
        #expect(await commits.next() != nil)
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "CREATE TABLE third (id INTEGER PRIMARY KEY)")
        }
        #expect(await commits.next() != nil)
    }
}

extension `Caller Tests`.Trace {
    @Test func `the trace names each statement, the driver's transactions among them, on the thread that runs it`() async throws {
        let seen = Mutex<[String]>([])
        let main = Mutex<[Bool]>([])
        var configuration = SQLite.Configuration()
        configuration.trace = { statement in
            seen.withLock { $0.append(statement) }
            main.withLock { $0.append(Thread.isMainThread) }
        }
        let database = try SQLite.Database(configuration: configuration)
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)")
        }
        seen.withLock { $0 = [] }
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: ["a"])
            try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: ["b"])
        }
        #expect(
            seen.withLock { $0 } == [
                "BEGIN IMMEDIATE TRANSACTION",
                "INSERT INTO item (name) VALUES (?)",
                "INSERT INTO item (name) VALUES (?)",
                "COMMIT TRANSACTION",
            ])
        #expect(main.withLock { $0 }.allSatisfy { !$0 })
    }
}

extension `Caller Tests`.Files {
    @Test func `the path of a database in memory gives one database, not one for each connection`() async throws {
        let database = try await items(in: SQLite.Database(path: ":memory:"))
        try await add("a", to: database)
        #expect(try await database.read { connection throws(ISO.`9075`.Error) in try names(connection) } == ["a"])
        #expect(try namesNow(database) == ["a"])
    }

    @Test func `a file opens again right after its database closed`() async throws {
        let path = try Scratch.path()
        for round in 0..<40 {
            let database = try SQLite.Database(path: path)
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "CREATE TABLE IF NOT EXISTS item (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)")
                try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: ["\(round)"])
            }
            _ = try await database.read { connection throws(ISO.`9075`.Error) in try names(connection) }
            _ = try namesNow(database)
            database.close()
        }
    }
}
