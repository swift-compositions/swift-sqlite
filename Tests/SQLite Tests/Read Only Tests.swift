#if GRDB
    import Foundation
    import Path
    import SQLite
    import SQLite_Test_Support
    import Testing

    @Suite struct `Read Only Tests` {
        static func folder() throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }

        static func restoredStore(in folder: URL) throws -> String {
            let path = folder.appending(path: "store.sqlite").path(percentEncoded: false)
            do {
                let database = try SQLite.Database(path: try Path::Path(validating: path))
                try database.write { connection in
                    try connection.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)")
                    try connection.execute(sql: "INSERT INTO item (id) VALUES (1)")
                }
            }
            // A copied or restored store has only its main file.
            try? FileManager.default.removeItem(atPath: path + "-shm")
            try? FileManager.default.removeItem(atPath: path + "-wal")
            return path
        }

        static var readonly: SQLite.Configuration {
            var configuration = SQLite.Configuration()
            configuration.readonly = true
            return configuration
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a restored store in WAL mode reads`(kind: SQLite.Database.Kind) throws {
            let path = try Self.restoredStore(in: Self.folder())
            let database = try SQLite.Database(path: try Path::Path(validating: path), kind: kind, configuration: Self.readonly)
            #expect(try database.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item") } == 1)
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a read-only database refuses a write`(kind: SQLite.Database.Kind) throws {
            let path = try Self.restoredStore(in: Self.folder())
            let database = try SQLite.Database(path: try Path::Path(validating: path), kind: kind, configuration: Self.readonly)
            #expect(throws: (any Error).self) {
                try database.write { try $0.execute(sql: "INSERT INTO item (id) VALUES (2)") }
            }
            #expect(try database.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item") } == 1)
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a store with its shm file still opens read-only`(kind: SQLite.Database.Kind) throws {
            let path = try Self.folder().appending(path: "live.sqlite").path(percentEncoded: false)
            let writer = try SQLite.Database(path: try Path::Path(validating: path))
            try writer.write { try $0.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)") }
            #expect(FileManager.default.fileExists(atPath: path + "-shm"))
            let database = try SQLite.Database(path: try Path::Path(validating: path), kind: kind, configuration: Self.readonly)
            #expect(try database.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item") } == 0)
            #expect(throws: (any Error).self) {
                try database.write { try $0.execute(sql: "INSERT INTO item (id) VALUES (2)") }
            }
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a read-only open creates nothing`(kind: SQLite.Database.Kind) throws {
            let path = try Self.folder().appending(path: "absent.sqlite").path(percentEncoded: false)
            #expect(throws: SQLite.Error.self) {
                _ = try SQLite.Database(path: try Path::Path(validating: path), kind: kind, configuration: Self.readonly)
            }
            #expect(!FileManager.default.fileExists(atPath: path))
        }
    }
#endif
