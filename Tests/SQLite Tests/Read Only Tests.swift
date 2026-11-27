import Foundation
import ISO_9075_Call_Level_Interface
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

    static func restoredStore(in folder: URL) async throws -> String {
        let path = folder.appending(path: "store.sqlite").path(percentEncoded: false)
        do {
            let database = try SQLite.Database(path: try Path::Path(validating: path))
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)")
                try connection.execute(sql: "INSERT INTO item (id) VALUES (1)")
            }
            database.close()
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

    static func count(_ database: SQLite.Database) async throws -> Int? {
        try await database.read { connection throws(ISO.`9075`.Error) in
            try Int.fetchOne(connection, sql: "SELECT count(*) FROM item")
        }
    }

    static func insert(_ id: Int, into database: SQLite.Database) async throws(ISO.`9075`.Error) {
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO item (id) VALUES (\(id))")
        }
    }

    @Test func `a restored store in WAL mode reads`() async throws {
        let path = try await Self.restoredStore(in: Self.folder())
        let database = try SQLite.Database(path: try Path::Path(validating: path), configuration: Self.readonly)
        #expect(try await Self.count(database) == 1)
    }

    @Test func `a read-only database refuses a write`() async throws {
        let path = try await Self.restoredStore(in: Self.folder())
        let database = try SQLite.Database(path: try Path::Path(validating: path), configuration: Self.readonly)
        await #expect(throws: ISO.`9075`.Error.self) {
            try await Self.insert(2, into: database)
        }
        #expect(try await Self.count(database) == 1)
    }

    @Test func `a read-only database still refuses a write after a read`() async throws {
        let path = try await Self.restoredStore(in: Self.folder())
        let database = try SQLite.Database(path: try Path::Path(validating: path), configuration: Self.readonly)
        let first = await #expect(throws: ISO.`9075`.Error.self) {
            try await Self.insert(2, into: database)
        }
        #expect(first.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .readonly)
        #expect(try await Self.count(database) == 1)
        let second = await #expect(throws: ISO.`9075`.Error.self) {
            try await Self.insert(3, into: database)
        }
        #expect(second.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .readonly)
        #expect(try await Self.count(database) == 1)
    }

    @Test func `a store with its shm file still opens read-only`() async throws {
        let path = try Self.folder().appending(path: "live.sqlite").path(percentEncoded: false)
        let writer = try SQLite.Database(path: try Path::Path(validating: path))
        try await writer.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)")
        }
        #expect(FileManager.default.fileExists(atPath: path + "-shm"))
        let database = try SQLite.Database(path: try Path::Path(validating: path), configuration: Self.readonly)
        #expect(try await Self.count(database) == 0)
        await #expect(throws: ISO.`9075`.Error.self) {
            try await Self.insert(2, into: database)
        }
    }

    @Test func `a read-only open creates nothing`() throws {
        let path = try Self.folder().appending(path: "absent.sqlite").path(percentEncoded: false)
        #expect(throws: SQLite.Error.self) {
            _ = try SQLite.Database(path: try Path::Path(validating: path), configuration: Self.readonly)
        }
        #expect(!FileManager.default.fileExists(atPath: path))
    }
}
