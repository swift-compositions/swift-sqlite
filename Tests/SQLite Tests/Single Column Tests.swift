import ISO_9075_Call_Level_Interface
import SQL
import SQL_Macros
import SQLite
import Testing

@Table
private struct Reading {
    let id: Int
    var value = 0
}

@Table
private struct Source {
    let id: Int
    var reading: Int
    var origin: String?
}

@Suite(.timeLimit(.minutes(5))) struct `A single column` {
    let database: SQLite.Database

    init() async throws {
        database = try SQLite.Database()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try #sql(#"CREATE TABLE "reading" ("id" INTEGER PRIMARY KEY, "value" INTEGER NOT NULL)"#).execute(connection)
            try #sql(#"CREATE TABLE "source" ("id" INTEGER PRIMARY KEY, "reading" INTEGER NOT NULL, "origin" TEXT)"#).execute(connection)
            try Reading.insert { Reading(id: 7, value: 3) }.execute(connection)
            try Source.insert { Source(id: 1, reading: 7, origin: "a") }.execute(connection)
        }
    }

    @Test func `fetched and converted in one chain keeps its value`() async throws {
        let maximum = try await database.read { connection throws(ISO.`9075`.Error) in
            let maximum = try Reading.select { $0.id.max() }.fetch.one(connection).flatMap { $0 }.map(Int64.init)
            return maximum
        }
        #expect(maximum == 7)
    }

    @Test func `selected from a join and converted in one chain keeps its value`() async throws {
        let maximum = try await database.read { connection throws(ISO.`9075`.Error) in
            let maximum = try Reading.join(Source.all) { $0.id.eq($1.reading) }
                .where { _, source in source.origin.eq("a") }
                .select { reading, _ in reading.id.max() }.fetch.one(connection).flatMap { $0 }.map(Int64.init)
            return maximum
        }
        #expect(maximum == 7)
    }

    @Test func `a single returned column is its value`() async throws {
        let id = try await database.write { connection throws(ISO.`9075`.Error) in
            // The connection is a parameter: a local function that captures the lent connection crashes the compiler.
            func insert(_ value: Int, _ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Int {
                try Reading.insert { Reading.Draft(value: value) }.returning(\.id).fetch.one(connection)!
            }
            return try insert(4, connection)
        }
        #expect(id == 8)
    }

    @Test func `fetched first keeps its value`() async throws {
        let maximum = try await database.read { connection throws(ISO.`9075`.Error) in
            try Reading.select { $0.id.max() }.fetch.one(connection)
        }
        #expect(maximum == 7)
    }
}
