#if Observation
    import GRDB
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

    func chores() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try queue.write { database in
            try database.execute(sql: #"CREATE TABLE "chores" ("id" INTEGER PRIMARY KEY, "title" TEXT NOT NULL, "list" TEXT)"#)
            try database.execute(sql: #"INSERT INTO "chores" VALUES (1, 'Milk', 'Home'), (2, 'Report', 'Work'), (3, 'Bread', 'Home'), (4, 'Idea', NULL)"#)
        }
        return queue
    }

    @MainActor
    @Suite struct `A sectioned fetch` {
        @Test func `rows are grouped under their section, in section order`() throws {
            @FetchAll(sectionBy: { $0.list }, database: try chores()) var all: [Chore]
            #expect(_all.sections.sectionNames == [nil, "Home", "Work"])
            #expect(_all.sections[sectionName: "Home"].map { $0.map(\.title) } == ["Milk", "Bread"])
            #expect(all.count == 4)
        }

        @Test func `an unsectioned fetch is one unnamed section`() throws {
            @FetchAll(Chore.order(by: \.id), database: try chores()) var all: [Chore]
            #expect(_all.sections.sectionNames == [nil])
            #expect(all.map(\.title) == ["Milk", "Report", "Bread", "Idea"])
        }

        @Test func `a statement can be sectioned by an ordering term`() throws {
            @FetchAll(Chore.select(\.title), sectionBy: { $0.list.desc() }, database: try chores()) var titles: [String]
            #expect(_titles.sections.sectionNames == ["Work", "Home", nil])
        }
    }
#endif
