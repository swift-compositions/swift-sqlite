#if CloudKit && canImport(CloudKit)
    import CloudKit
    import Foundation
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    @_spi(Testing) import SQLite_CloudKit
    import Testing

    /// Several devices on one ``TestCloud``: what each one writes, and deletes, reaches every other.
    @Suite struct TestCloudTests {
        @Table("notes") struct Note: Equatable {
            let id: String
            var body: String
        }

        struct Device {
            let database: DatabaseQueue
            let engine: SyncEngine

            init(cloud: TestCloud) throws {
                database = try DatabaseQueue()
                try database.write {
                    try $0.execute(sql: "CREATE TABLE notes (id TEXT PRIMARY KEY NOT NULL, body TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '') STRICT")
                }
                engine = try SyncEngine(for: database, tables: Note.self, cloud: cloud)
            }

            func start() async throws {
                try await engine.start()
                await engine.receiveAccountChange(.signIn(currentUser: CKRecord.ID(recordName: "_user")))
            }

            func sync() async throws {
                try await engine.sendChanges()
                try await engine.fetchChanges()
            }

            func ids() throws -> [String] {
                try database.read { try String.fetchAll($0, sql: "SELECT id FROM notes ORDER BY id") }
            }
        }

        @Test func `a deletion reaches every device, not only the first to fetch`() async throws {
            let cloud = TestCloud()
            let devices = try (0..<3).map { _ in try Device(cloud: cloud) }
            for device in devices { try await device.start() }
            try await devices[0].database.write {
                try $0.execute(sql: "INSERT INTO notes (id, body) VALUES ('a', 'one'), ('b', 'two')")
            }
            for device in devices { try await device.sync() }
            #expect(try devices.allSatisfy { try $0.ids() == ["a", "b"] })

            try await devices[1].database.write { try $0.execute(sql: "DELETE FROM notes WHERE id = 'a'") }
            try await devices[1].sync()
            try await devices[0].sync()
            try await devices[2].sync()
            for device in devices { #expect(try device.ids() == ["b"]) }
            #expect(cloud.recordNames(in: devices[0].engine.zoneID) == ["b:notes"])
        }

        @Test func `more changes than one batch holds all reach the cloud in one send`() async throws {
            let cloud = TestCloud()
            let device = try Device(cloud: cloud), other = try Device(cloud: cloud)
            try await device.start()
            try await other.start()
            try await device.database.write { db in
                for index in 0..<450 { try db.execute(sql: "INSERT INTO notes (id, body) VALUES (?, 'x')", arguments: ["n\(index)"]) }
            }
            try await device.sync()
            #expect(cloud.recordNames(in: device.engine.zoneID).count == 450)
            try await other.sync()
            #expect(try other.ids().count == 450)
        }
    }
#endif
