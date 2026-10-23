#if CloudKit && canImport(CloudKit)
    import CloudKit
    import Foundation
    import SQL
    import SQL_Macros
    import SQLite
    @_spi(Testing) import SQLite_CloudKit
    import Testing

    /// Several devices on one ``SyncEngine/Mock``: what each one writes, and deletes, reaches every other.
    extension SyncEngine.Mock {
        @Suite struct Devices {
            @Table("notes") struct Note: Equatable {
                let id: String
                var body: String
            }

            struct Device {
                let database: SQLite.Database
                let engine: SyncEngine

                init(mock: SyncEngine.Mock) throws {
                    database = try SQLite.Database()
                    try database.write {
                        try #sql("CREATE TABLE notes (id TEXT PRIMARY KEY NOT NULL, body TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '') STRICT").execute($0)
                    }
                    engine = try SyncEngine(for: database, tables: Note.self, mock: mock)
                }

                func start() async throws {
                    try await engine.start()
                    await engine.receive(.signIn(currentUser: CKRecord.ID(recordName: "_user")))
                }

                func sync() async throws {
                    try await engine.sendChanges()
                    try await engine.fetchChanges()
                }

                func ids() throws -> [String] {
                    try database.read { try Note.order(by: \.id).select(\.id).fetchAll($0) }
                }
            }

            @Test func `a deletion reaches every device, not only the first to fetch`() async throws {
                let mock = SyncEngine.Mock()
                let devices = try (0..<3).map { _ in try Device(mock: mock) }
                for device in devices { try await device.start() }
                try await devices[0].database.write {
                    try #sql("INSERT INTO notes (id, body) VALUES ('a', 'one'), ('b', 'two')").execute($0)
                }
                for device in devices { try await device.sync() }
                #expect(try devices.allSatisfy { try $0.ids() == ["a", "b"] })

                try await devices[1].database.write { try #sql("DELETE FROM notes WHERE id = 'a'").execute($0) }
                try await devices[1].sync()
                try await devices[0].sync()
                try await devices[2].sync()
                for device in devices { #expect(try device.ids() == ["b"]) }
                #expect(mock.records(in: devices[0].engine.zone).map(\.recordID.recordName) == ["b:notes"])
            }

            @Test func `more changes than one batch holds all reach the cloud in one send`() async throws {
                let mock = SyncEngine.Mock()
                let device = try Device(mock: mock)
                let other = try Device(mock: mock)
                try await device.start()
                try await other.start()
                try await device.database.write { db in
                    for index in 0..<450 { try Note.insert { Note(id: "n\(index)", body: "x") }.execute(db) }
                }
                try await device.sync()
                #expect(mock.records(in: device.engine.zone).count == 450)
                try await other.sync()
                #expect(try other.ids().count == 450)
            }
        }
    }
#endif
