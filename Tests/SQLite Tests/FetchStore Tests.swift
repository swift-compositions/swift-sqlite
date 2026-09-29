#if Observation
    import Dispatch
    import GRDB
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
        func fetch(_ database: GRDB.Database) throws -> [String] {
            try String.fetchAll(database, sql: #"SELECT "title" FROM "reminder" ORDER BY "title""#)
        }
    }

    struct Failing: FetchKeyRequest {
        func fetch(_ database: GRDB.Database) throws -> [String] {
            try String.fetchAll(database, sql: #"SELECT "title" FROM "missing""#)
        }
    }

    @MainActor
    func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func reminders() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try queue.write { database in
            try database.execute(sql: #"CREATE TABLE "reminder" ("title" TEXT NOT NULL)"#)
            try database.execute(sql: #"INSERT INTO "reminder" VALUES ('Groceries')"#)
        }
        return queue
    }

    @MainActor
    @Suite struct `An observed fetch` {
        @Test func `the store holds the fetched value at once`() throws {
            let store = FetchStore(value: [], Titles(), database: try reminders())
            #expect(store.value == ["Groceries"])
            #expect(!store.isLoading)
        }

        @Test func `a write elsewhere reaches the store`() async throws {
            let queue = try reminders()
            let store = FetchStore(value: [], Titles(), database: queue)
            try await queue.write { database in try database.execute(sql: #"INSERT INTO "reminder" VALUES ('Call mom')"#) }
            await eventually { store.value.count == 2 }
            #expect(store.value == ["Call mom", "Groceries"])
        }

        @Test func `every change is delivered through the given scheduler`() async throws {
            let queue = try reminders()
            let scheduler = Recording()
            let store = FetchStore(value: [], Titles(), database: queue, scheduling: scheduler)
            try await queue.write { database in try database.execute(sql: #"INSERT INTO "reminder" VALUES ('Taxes')"#) }
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
            let queue = try reminders()
            let store = FetchStore(value: [], Titles(), database: queue)
            store.cancel()
            try await queue.write { database in try database.execute(sql: #"INSERT INTO "reminder" VALUES ('Late')"#) }
            try await Task.sleep(for: .milliseconds(100))
            #expect(store.value == ["Groceries"])
        }

        #if canImport(SwiftUI)
            @Test func `an animated store receives each change inside its animation`() async throws {
                let queue = try reminders()
                let store = FetchStore(value: [], Titles(), database: queue, scheduling: .animation(.default))
                #expect(store.value == ["Groceries"])
                try await queue.write { database in try database.execute(sql: #"INSERT INTO "reminder" VALUES ('Dentist')"#) }
                await eventually { store.value.count == 2 }
                #expect(store.value == ["Dentist", "Groceries"])
            }
        #endif
    }
#endif
