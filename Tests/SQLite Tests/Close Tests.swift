#if GRDB
    import Foundation
    import Path
    import SQLite
    import SQLite_Test_Support
    import Testing

    @Suite struct `Close Tests` {
        static func closed(kind: SQLite.Database.Kind) throws -> SQLite.Database {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let path = folder.appending(path: "store.sqlite").path(percentEncoded: false)
            let database = try SQLite.Database(path: try Path::Path(validating: path), kind: kind)
            try database.close()
            return database
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a read after close throws`(kind: SQLite.Database.Kind) throws {
            let database = try Self.closed(kind: kind)
            let error = #expect(throws: SQLite.Error.self) {
                try database.read { try Int.fetchOne($0, sql: "SELECT 1") }
            }
            #expect(error?.code == .misuse)
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a write after close throws`(kind: SQLite.Database.Kind) throws {
            let database = try Self.closed(kind: kind)
            let error = #expect(throws: SQLite.Error.self) {
                try database.write { try $0.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)") }
            }
            #expect(error?.code == .misuse)
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a write outside a transaction after close throws`(kind: SQLite.Database.Kind) throws {
            let database = try Self.closed(kind: kind)
            let error = #expect(throws: SQLite.Error.self) {
                try database.writeWithoutTransaction { try $0.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)") }
            }
            #expect(error?.code == .misuse)
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `an asynchronous read after close throws`(kind: SQLite.Database.Kind) async throws {
            let database = try Self.closed(kind: kind)
            let error = await #expect(throws: SQLite.Error.self) {
                try await database.read { try Int.fetchOne($0, sql: "SELECT 1") }
            }
            #expect(error?.code == .misuse)
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `an asynchronous write after close throws`(kind: SQLite.Database.Kind) async throws {
            let database = try Self.closed(kind: kind)
            let error = await #expect(throws: SQLite.Error.self) {
                try await database.write { try $0.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)") }
            }
            #expect(error?.code == .misuse)
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `a copy of the database is closed too`(kind: SQLite.Database.Kind) throws {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let path = folder.appending(path: "store.sqlite").path(percentEncoded: false)
            let database = try SQLite.Database(path: try Path::Path(validating: path), kind: kind)
            let copy = database
            try database.close()
            #expect(throws: SQLite.Error.self) {
                try copy.read { try Int.fetchOne($0, sql: "SELECT 1") }
            }
        }

        @Test(arguments: [SQLite.Database.Kind.pool, .queue])
        func `closing twice does nothing`(kind: SQLite.Database.Kind) throws {
            let database = try Self.closed(kind: kind)
            try database.close()
        }
    }
#endif
