#if Observation
    // A consumer of swift-sqlite, as an app or a domain package is one: it imports the Institute's modules only, never the
    // driver. That this target compiles is the evidence that the whole workflow below needs no driver type.
    import ISO_9075_Call_Level_Interface
    import SQL
    import SQL_Macros
    import SQL_Migrations
    import SQLite
    import Testing

    #if CloudKit && canImport(CloudKit)
        import CloudKit
        @_spi(Testing) import SQLite_CloudKit
    #endif

    @Table("items")
    struct Item: Equatable, Identifiable {
        let id: String
        var title = ""
        var isDone = false
    }

    extension Item {
        static var migrator: Migrator<SQLite.Database> {
            var migrator = Migrator<SQLite.Database>()
            migrator.register("Create items") { connection throws(ISO_9075.Error) in
                _ = try connection.execute(
                    """
                    CREATE TABLE "items" (
                      "id" TEXT PRIMARY KEY NOT NULL,
                      "title" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                      "isDone" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
                    ) STRICT
                    """
                )
            }
            return migrator
        }

        static func database() async throws -> SQLite.Database {
            let database = try SQLite.Database()
            try await migrator.migrate(database)
            try await database.write { connection in
                try connection.seed {
                    Item(id: "a", title: "Groceries")
                    Item(id: "b", title: "Taxes", isDone: true)
                }
            }
            return database
        }
    }

    @MainActor
    @Suite struct `A consumer without the driver` {
        @Test func `migrates, seeds and executes typed statements`() async throws {
            let database = try await Item.database()
            try await database.write { connection in
                try Item.insert { Item(id: "c", title: "Dentist") }.execute(connection)
                try Item.find("a").update { $0.isDone = true }.execute(connection)
            }
            let (done, count, dentist) = try await database.read { connection in
                (
                    try Item.where(\.isDone).order(by: \.id).select(\.id).fetchAll(connection),
                    try Item.fetchCount(connection),
                    try Item.find(connection, key: "c")
                )
            }
            #expect(done == ["a", "b"])
            #expect(count == 3)
            #expect(dentist == Item(id: "c", title: "Dentist"))
        }

        @Test func `a failing statement throws the institute's error`() async throws {
            let database = try await Item.database()
            await #expect(throws: SQLite.Error.self) {
                try await database.write { connection in
                    try Item.insert { Item(id: "a", title: "Duplicate") }.execute(connection)
                }
            }
            do {
                try await database.write { connection in
                    try Item.insert { Item(id: "a", title: "Duplicate") }.execute(connection)
                }
                Issue.record("A duplicate primary key was inserted")
            } catch let error as SQLite.Error {
                #expect(error.code == .constraint)
                #expect(error.extendedCode == .primaryKeyConstraint)
            }
        }

        @Test func `observes with FetchAll`() async throws {
            let database = try await Item.database()
            @FetchAll(Item.order(by: \.id), database: database) var items: [Item]
            #expect(items.map(\.id) == ["a", "b"])
            try await database.write { connection in
                try Item.insert { Item(id: "c") }.execute(connection)
            }
            for _ in 0..<200 where items.count < 3 {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(items.map(\.id) == ["a", "b", "c"])
        }

        #if CloudKit && canImport(CloudKit)
            @Test func `starts a sync engine and sends what it writes`() async throws {
                let mock = SyncEngine.Mock()
                let database = try await Item.database()
                let engine = try SyncEngine(for: database, tables: Item.self, mock: mock)
                try await engine.start()
                await engine.receive(.signIn(currentUser: CKRecord.ID(recordName: "_user")))
                try await database.write { connection in
                    try Item.insert { Item(id: "c", title: "Dentist") }.execute(connection)
                }
                try await engine.sendChanges()
                #expect(
                    mock.records(in: engine.zone).map(\.recordID.recordName).sorted() == ["a:items", "b:items", "c:items"]
                )
            }
        #endif
    }
#endif
