#if GRDB
    import GRDB
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

    @Suite struct `Text with NUL characters` {
        let queue: DatabaseQueue

        init() throws {
            queue = try DatabaseQueue()
            try queue.write { database in
                try database.execute(
                    sql: """
                        CREATE TABLE "record" (
                          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                          "value" TEXT NOT NULL
                        ) STRICT
                        """
                )
            }
        }

        @Test func `decodes past the NUL`() throws {
            let value = try queue.read { database in
                try #sql("SELECT 'a' || char(0) || 'b'", as: String.self).fetchOne(database)
            }
            #expect(value == textWithNul)
        }

        @Test func `binds and fetches past the NUL`() throws {
            let echoed = try queue.read { database in
                try #sql("SELECT \(bind: textWithNul)", as: String.self).fetchOne(database)
            }
            #expect(echoed == textWithNul)
            let inserted = try #require(
                try queue.write { database in
                    try Record.insert { Record.Draft(value: textWithNul) }
                        .returning(\.self)
                        .fetchOne(database)
                }
            )
            #expect(inserted.value == textWithNul)
        }
    }
#endif
