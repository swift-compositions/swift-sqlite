#if Observation
    import ISO_9075_Call_Level_Interface
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    #if canImport(SwiftUI)
        import SwiftUI
    #endif

    /// Counts the changes a scheduler was given, on the actor that takes them.
    @MainActor
    final class Deliveries {
        var count = 0
    }

    struct Titles: FetchKeyRequest {
        func fetch(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> [String] {
            try #sql(#"SELECT "title" FROM "reminder" ORDER BY "title""#, as: String.self).fetch.all(connection)
        }
    }

    /// Fails for as long as there is no table "late".
    struct Late: FetchKeyRequest {
        func fetch(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> [String] {
            try #sql(#"SELECT "title" FROM "late""#, as: String.self).fetch.all(connection)
        }
    }

    /// A value that is not `Equatable`.
    struct Count: Sendable {
        var rows: Int
    }

    struct Counting: FetchKeyRequest {
        func fetch(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Count {
            Count(rows: try #sql(#"SELECT count(*) FROM "reminder""#, as: Int.self).fetch.one(connection) ?? 0)
        }
    }

    func reminders(file: Bool = false) async throws -> SQLite.Database {
        let database = try file ? SQLite.Database(path: Scratch.path()) : SQLite.Database()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try #sql(#"CREATE TABLE "reminder" ("title" TEXT NOT NULL)"#).execute(connection)
            try #sql(#"CREATE TABLE "note" ("body" TEXT NOT NULL)"#).execute(connection)
            try #sql(#"INSERT INTO "reminder" VALUES ('Groceries')"#).execute(connection)
        }
        return database
    }

    func insert(_ title: String, into database: SQLite.Database) async throws {
        try await database.write { connection throws(ISO.`9075`.Error) in
            try #sql(#"INSERT INTO "reminder" VALUES (\#(bind: title))"#).execute(connection)
        }
    }

    @MainActor
    @Suite(.timeLimit(.minutes(1))) struct `An observed fetch` {
        @Test(arguments: [true, false])
        func `the store holds the fetched value at once`(file: Bool) async throws {
            let store = FetchStore(value: [], Titles(), database: try await reminders(file: file))
            #expect(store.value == ["Groceries"])
            #expect(!store.isLoading)
        }

        @Test(arguments: [true, false])
        func `when a write returns, the store holds what was written`(file: Bool) async throws {
            let database = try await reminders(file: file)
            let store = FetchStore(value: [], Titles(), database: database)
            for number in 1...100 {
                try await insert("\(1000 + number)", into: database)
                #expect(store.value.count == number + 1)
            }
        }

        @Test func `when a write returns, every store holds what was written`() async throws {
            let database = try await reminders()
            let stores = (0..<4).map { _ in FetchStore(value: [], Titles(), database: database) }
            try await insert("Call mom", into: database)
            for store in stores { #expect(store.value == ["Call mom", "Groceries"]) }
        }

        @Test func `every later change is taken through the given scheduler, and the first is not`() async throws {
            let database = try await reminders()
            let deliveries = Deliveries()
            let scheduler = SQLite.Scheduler { change in
                deliveries.count += 1
                change()
            }
            let store = FetchStore(value: [], Titles(), database: database, scheduling: scheduler)
            #expect(deliveries.count == 0)
            try await insert("Taxes", into: database)
            #expect(store.value == ["Groceries", "Taxes"])
            #expect(deliveries.count == 1)
        }

        @Test func `a write that leaves an Equatable value equal does not change the store`() async throws {
            let database = try await reminders()
            let deliveries = Deliveries()
            let scheduler = SQLite.Scheduler { change in
                deliveries.count += 1
                change()
            }
            let store = FetchStore(value: [], Titles(), database: database, scheduling: scheduler)
            try await database.write { connection throws(ISO.`9075`.Error) in
                try #sql(#"INSERT INTO "note" VALUES ('unrelated')"#).execute(connection)
            }
            #expect(deliveries.count == 0)
            #expect(store.value == ["Groceries"])
        }

        @Test func `a value that is not Equatable is taken again at every commit`() async throws {
            let database = try await reminders()
            let deliveries = Deliveries()
            let scheduler = SQLite.Scheduler { change in
                deliveries.count += 1
                change()
            }
            let store = FetchStore(value: Count(rows: 0), Counting(), database: database, scheduling: scheduler)
            #expect(store.value.rows == 1)
            try await database.write { connection throws(ISO.`9075`.Error) in
                try #sql(#"INSERT INTO "note" VALUES ('unrelated')"#).execute(connection)
            }
            #expect(deliveries.count == 1)
            try await insert("Taxes", into: database)
            #expect(store.value.rows == 2)
            #expect(deliveries.count == 2)
        }

        @Test func `a failing fetch keeps the last value, reports the error, and is followed until it reads`() async throws {
            let database = try await reminders()
            let store = FetchStore(value: ["kept"], Late(), database: database)
            #expect(store.value == ["kept"])
            #expect(store.loadError != nil)
            try await database.write { connection throws(ISO.`9075`.Error) in
                try #sql(#"CREATE TABLE "late" ("title" TEXT NOT NULL)"#).execute(connection)
                try #sql(#"INSERT INTO "late" VALUES ('Arrived')"#).execute(connection)
            }
            #expect(store.value == ["Arrived"])
            #expect(store.loadError == nil)
        }

        @Test func `a cancelled store stops following writes, and holds no write back`() async throws {
            let database = try await reminders()
            let store = FetchStore(value: [], Titles(), database: database)
            store.cancel()
            try await insert("Late", into: database)
            #expect(store.value == ["Groceries"])
        }

        @Test func `a store that is gone holds no write back`() async throws {
            let database = try await reminders()
            do {
                let store = FetchStore(value: [], Titles(), database: database)
                #expect(store.value == ["Groceries"])
            }
            try await insert("Late", into: database)
        }

        @Test func `a store that starts again follows its new request only`() async throws {
            let database = try await reminders()
            let store = FetchStore<[String]>(value: [])
            try await store.load(Titles(), database: database)
            try await database.write { connection throws(ISO.`9075`.Error) in
                try #sql(#"CREATE TABLE "late" ("title" TEXT NOT NULL)"#).execute(connection)
            }
            try await store.load(Late(), database: database)
            #expect(store.value == [])
            try await insert("Ignored", into: database)
            #expect(store.value == [])
        }

        @Test(arguments: [true, false])
        func `an awaited load returns once the first value is in and keeps following`(file: Bool) async throws {
            let database = try await reminders(file: file)
            let store = FetchStore<[String]>(value: [])
            try await store.load(Titles(), database: database)
            #expect(store.value == ["Groceries"])
            #expect(!store.isLoading)
            try await insert("Call mom", into: database)
            #expect(store.value == ["Call mom", "Groceries"])
        }

        @Test func `an awaited load throws the request's error and keeps the last value`() async throws {
            let database = try await reminders()
            let store = FetchStore(value: ["kept"])
            await #expect(throws: ISO.`9075`.Error.self) { try await store.load(Late(), database: database) }
            #expect(store.value == ["kept"])
            #expect(store.loadError != nil)
        }

        @Test func `cancelling the subscription's task ends the observation`() async throws {
            let database = try await reminders()
            let store = FetchStore<[String]>(value: [])
            let subscription = try await store.load(Titles(), database: database)
            let following = Task { try await subscription.task }
            following.cancel()
            await #expect(throws: CancellationError.self) { try await following.value }
            try await insert("Late", into: database)
            #expect(store.value == ["Groceries"])
        }

        #if canImport(SwiftUI)
            @Test func `an animated store holds each change when its write returns`() async throws {
                let database = try await reminders()
                let store = FetchStore(value: [], Titles(), database: database, scheduling: .animation(.default))
                #expect(store.value == ["Groceries"])
                try await insert("Dentist", into: database)
                #expect(store.value == ["Dentist", "Groceries"])
            }
        #endif
    }
#endif
