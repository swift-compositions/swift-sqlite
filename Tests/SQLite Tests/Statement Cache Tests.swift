import Cardinal
import ISO_9075_Call_Level_Interface
import SQL
import SQL_Macros
import SQLite
import Testing

@Table
private struct Record: Equatable {
    let id: Int
    var value: String
}

@Suite(.timeLimit(.minutes(5))) struct `The statement cache` {
    let queue: SQLite.Database

    init() async throws {
        queue = try SQLite.Database()
        try await queue.write { connection throws(ISO.`9075`.Error) in
            try #sql(
                #"CREATE TABLE "record" ("id" INTEGER PRIMARY KEY, "value" TEXT NOT NULL)"#
            )
            .execute(connection)
            for id in 1...10 {
                try Record.insert { Record(id: id, value: "value \(id)") }.execute(connection)
            }
        }
    }

    @Test func `rebinds a reused statement`() async throws {
        try await queue.read { connection throws(ISO.`9075`.Error) in
            for id in 1...10 {
                let record = try Record.where { $0.id.eq(id) }.fetch.one(connection)
                #expect(record?.id == id)
                #expect(record?.value == "value \(id)")
            }
        }
    }

    #if GRDB
        @Test func `does not share a statement with an escaping cursor`() throws {
            try queue.read { database in
                let query = Record.where { $0.id.lte(3) }
                let cursor = try query.fetchCursor(database)
                #expect(try cursor.next()?.id == 1)
                #expect(try query.fetch.all(database).map(\.id) == [1, 2, 3])
                #expect(try cursor.next()?.id == 2)
                #expect(try cursor.next()?.id == 3)
                #expect(try cursor.next() == nil)
            }
        }
    #endif

    @Test func `reuses a cached execute`() async throws {
        try await queue.write { connection throws(ISO.`9075`.Error) in
            for id in 11...20 {
                try Record.insert { Record(id: id, value: "value \(id)") }.execute(connection)
            }
            let count = try Record.all.fetch.count(connection)
            #expect(count == 20)
        }
    }

    @Test func `survives a schema change between uses`() async throws {
        try await queue.write { connection throws(ISO.`9075`.Error) in
            let before = try Record.all.fetch.count(connection)
            #expect(before == 10)
            try #sql(#"ALTER TABLE "record" ADD COLUMN "extra" TEXT"#).execute(connection)
            let after = try Record.all.fetch.count(connection)
            #expect(after == 10)
            let value = try Record.where { $0.id.eq(5) }.fetch.one(connection)?.value
            #expect(value == "value 5")
        }
    }
}
