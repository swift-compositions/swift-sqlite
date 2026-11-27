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

private let textWithNul = "a\u{0}b"

@Suite(.timeLimit(.minutes(5))) struct `Text with NUL characters` {
    let database: SQLite.Database

    init() async throws {
        database = try SQLite.Database()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try #sql(
                """
                CREATE TABLE "record" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "value" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(connection)
        }
    }

    @Test func `decodes past the NUL`() async throws {
        let value = try await database.read { connection throws(ISO.`9075`.Error) in
            try #sql("SELECT 'a' || char(0) || 'b'", as: String.self).fetch.one(connection)
        }
        #expect(value == textWithNul)
    }

    @Test func `binds and fetches past the NUL`() async throws {
        let echoed = try await database.read { connection throws(ISO.`9075`.Error) in
            try #sql("SELECT \(bind: textWithNul)", as: String.self).fetch.one(connection)
        }
        #expect(echoed == textWithNul)
        let inserted = try #require(
            try await database.write { connection throws(ISO.`9075`.Error) in
                try Record.insert { Record.Draft(value: textWithNul) }
                    .returning(\.self)
                    .fetch.one(connection)
            }
        )
        #expect(inserted.value == textWithNul)
    }
}
