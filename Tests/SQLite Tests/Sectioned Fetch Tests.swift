#if Observation
    import ISO_9075_Call_Level_Interface
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    struct Chore {
        let id: Int
        var title = ""
        var list: String?
    }

    func chores() async throws -> SQLite.Database {
        let database = try SQLite.Database()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try #sql(#"CREATE TABLE "chore" ("id" INTEGER PRIMARY KEY, "title" TEXT NOT NULL, "list" TEXT)"#).execute(connection)
            try #sql(#"INSERT INTO "chore" VALUES (1, 'Milk', 'Home'), (2, 'Report', 'Work'), (3, 'Bread', 'Home'), (4, 'Idea', NULL)"#).execute(connection)
        }
        return database
    }

    @MainActor
    @Suite(.timeLimit(.minutes(5))) struct `A sectioned fetch` {
        @Test func `rows are grouped under their section, in section order`() async throws {
            let database = try await chores()
            @FetchAll(sectionBy: { $0.list }, database: database) var all: [Chore]
            #expect(_all.sections.sectionNames == [nil, "Home", "Work"])
            #expect(_all.sections[sectionName: "Home"].map { $0.map(\.title) } == ["Milk", "Bread"])
            #expect(all.count == 4)
        }

        @Test func `an unsectioned fetch is one unnamed section`() async throws {
            let database = try await chores()
            @FetchAll(Chore.order(by: \.id), database: database) var all: [Chore]
            #expect(_all.sections.sectionNames == [nil])
            #expect(all.map(\.title) == ["Milk", "Report", "Bread", "Idea"])
        }

        @Test func `a statement can be sectioned by an ordering term`() async throws {
            let database = try await chores()
            @FetchAll(Chore.select(\.title), sectionBy: { $0.list.desc() }, database: database) var titles: [String]
            #expect(_titles.sections.sectionNames == ["Work", "Home", nil])
        }
    }
#endif
