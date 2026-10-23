#if Observation
    import Dispatch
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Synchronization
    import Testing

    #if canImport(SwiftUI)
        import SwiftUI
    #endif

    final class Recording: ValueObservationScheduler, Sendable {
        let deliveries = Mutex(0)

        func immediateInitialValue() -> Bool { true }

        func schedule(_ action: @escaping @Sendable () -> Void) {
            deliveries.withLock { $0 += 1 }
            DispatchQueue.main.async(execute: action)
        }
    }

    struct Titles: FetchKeyRequest {
        func fetch(_ connection: SQLite.Connection) throws -> [String] {
            try #sql(#"SELECT "title" FROM "reminder" ORDER BY "title""#, as: String.self).fetchAll(connection)
        }
    }

    struct Failing: FetchKeyRequest {
        func fetch(_ connection: SQLite.Connection) throws -> [String] {
            try #sql(#"SELECT "title" FROM "missing""#, as: String.self).fetchAll(connection)
        }
    }

    @MainActor
    func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func reminders() throws -> SQLite.Database {
        let database = try SQLite.Database()
        try database.write { connection in
            try #sql(#"CREATE TABLE "reminder" ("title" TEXT NOT NULL)"#).execute(connection)
            try #sql(#"INSERT INTO "reminder" VALUES ('Groceries')"#).execute(connection)
        }
        return database
    }

    func insert(_ title: String, into database: SQLite.Database) async throws {
        try await database.write { connection in
            try #sql(#"INSERT INTO "reminder" VALUES (\#(bind: title))"#).execute(connection)
        }
    }

    @MainActor
    @Suite struct `An observed fetch` {
        @Test func `the store holds the fetched value at once`() throws {
            let store = FetchStore(value: [], Titles(), database: try reminders())
            #expect(store.value == ["Groceries"])
            #expect(!store.isLoading)
        }

        @Test func `a write elsewhere reaches the store`() async throws {
            let database = try reminders()
            let store = FetchStore(value: [], Titles(), database: database)
            try await insert("Call mom", into: database)
            await eventually { store.value.count == 2 }
            #expect(store.value == ["Call mom", "Groceries"])
        }

        @Test func `every change is delivered through the given scheduler`() async throws {
            let database = try reminders()
            let scheduler = Recording()
            let store = FetchStore(value: [], Titles(), database: database, scheduling: SQLite.Scheduler(scheduler))
            try await insert("Taxes", into: database)
            await eventually { store.value.count == 2 }
            #expect(store.value == ["Groceries", "Taxes"])
            #expect(scheduler.deliveries.withLock { $0 } >= 1)
        }

        @Test func `a failing fetch keeps the last value and reports the error`() throws {
            let store = FetchStore(value: ["kept"], Failing(), database: try reminders())
            #expect(store.value == ["kept"])
            #expect(store.loadError != nil)
        }

        @Test func `a cancelled store stops following writes`() async throws {
            let database = try reminders()
            let store = FetchStore(value: [], Titles(), database: database)
            store.cancel()
            try await insert("Late", into: database)
            try await Task.sleep(for: .milliseconds(100))
            #expect(store.value == ["Groceries"])
        }

        @Test func `an awaited load returns once the first value is in and keeps following`() async throws {
            let database = try reminders()
            let store = FetchStore<[String]>(value: [])
            try await store.load(Titles(), database: database)
            #expect(store.value == ["Groceries"])
            try await insert("Call mom", into: database)
            await eventually { store.value.count == 2 }
            #expect(store.value == ["Call mom", "Groceries"])
        }

        @Test func `an awaited load throws the request's error and keeps the last value`() async throws {
            let store = FetchStore(value: ["kept"])
            await #expect(throws: (any Error).self) { try await store.load(Failing(), database: try reminders()) }
            #expect(store.value == ["kept"])
            #expect(store.loadError != nil)
        }

        @Test func `cancelling the subscription's task ends the observation`() async throws {
            let database = try reminders()
            let store = FetchStore<[String]>(value: [])
            let subscription = try await store.load(Titles(), database: database)
            let following = Task { try await subscription.task }
            try await Task.sleep(for: .milliseconds(20))
            following.cancel()
            await #expect(throws: CancellationError.self) { try await following.value }
            try await Task.sleep(for: .milliseconds(20))
            try await insert("Late", into: database)
            try await Task.sleep(for: .milliseconds(100))
            #expect(store.value == ["Groceries"])
        }

        #if canImport(SwiftUI)
            @Test func `an animated store receives each change inside its animation`() async throws {
                let database = try reminders()
                let store = FetchStore(value: [], Titles(), database: database, scheduling: .animation(.default))
                #expect(store.value == ["Groceries"])
                try await insert("Dentist", into: database)
                await eventually { store.value.count == 2 }
                #expect(store.value == ["Dentist", "Groceries"])
            }
        #endif
    }
#endif
