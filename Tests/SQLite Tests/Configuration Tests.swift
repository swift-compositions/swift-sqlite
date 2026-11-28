import Foundation
import ISO_9075_Call_Level_Interface
import Path
import SQLite
import SQLite_Test_Support
import Testing

private func size(_ path: Path::Path) throws -> Int {
    try FileManager.default.attributesOfItem(atPath: path.string)[.size] as? Int ?? 0
}

/// One write of 100 rows of 2 KB: some fifty pages of log.
private func fill(_ database: SQLite.Database) async throws {
    let body = String(repeating: "y", count: 2_048)
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(sql: "CREATE TABLE entry (id INTEGER PRIMARY KEY, body TEXT)")
        for _ in 0..<100 { try connection.execute(sql: "INSERT INTO entry (body) VALUES (?)", arguments: [body]) }
    }
}

@Suite struct `Configuration Tests` {
    @Suite struct Settings {}
    @Suite struct Checkpoints {}
}

extension `Configuration Tests`.Settings {
    @Test func `every connection has the cache and the memory mapping that were asked for`() async throws {
        var configuration = SQLite.Configuration()
        configuration.cache = .pages(321)
        configuration.memoryMappedByteCount = 1 << 20
        let database = try SQLite.Database(path: Scratch.path(), configuration: configuration)
        defer { database.close() }
        let writer = try await database.write { connection throws(ISO.`9075`.Error) in
            [try Int.fetchOne(connection, sql: "PRAGMA cache_size"), try Int.fetchOne(connection, sql: "PRAGMA mmap_size")]
        }
        let reader = try await database.read { connection throws(ISO.`9075`.Error) in
            [try Int.fetchOne(connection, sql: "PRAGMA cache_size"), try Int.fetchOne(connection, sql: "PRAGMA mmap_size")]
        }
        let direct = try synchronous(database)
        #expect(writer == [321, 1 << 20])
        #expect(reader == [321, 1 << 20])
        #expect(direct == [321, 1 << 20])
    }

    private func synchronous(_ database: SQLite.Database) throws -> [Int?] {
        try database.read { connection throws(ISO.`9075`.Error) in
            [try Int.fetchOne(connection, sql: "PRAGMA cache_size"), try Int.fetchOne(connection, sql: "PRAGMA mmap_size")]
        }
    }

    @Test func `a cache in kibibytes is SQLite's negative size`() async throws {
        var configuration = SQLite.Configuration()
        configuration.cache = .kibibytes(512)
        for database in [try SQLite.Database(configuration: configuration), try SQLite.Database(path: Scratch.path(), configuration: configuration)] {
            let cache = try await database.read { connection throws(ISO.`9075`.Error) in
                try Int.fetchOne(connection, sql: "PRAGMA cache_size")
            }
            #expect(cache == -512)
            database.close()
        }
    }

    @Test func `an automatic checkpoint is set on the connection that writes`() async throws {
        for pages in [0, 7] {
            var configuration = SQLite.Configuration()
            configuration.checkpoint = .automatic(pages: pages)
            let database = try SQLite.Database(path: Scratch.path(), configuration: configuration)
            let set = try await database.write { connection throws(ISO.`9075`.Error) in
                try Int.fetchOne(connection, sql: "PRAGMA wal_autocheckpoint")
            }
            #expect(set == pages)
            database.close()
        }
    }
}

extension `Configuration Tests`.Checkpoints {
    @Test func `the log is copied back beside the writer after a write that fills it`() async throws {
        var never = SQLite.Configuration()
        never.checkpoint = .automatic(pages: 0)
        var beside = SQLite.Configuration()
        beside.checkpoint = .concurrent(pages: 10, limit: 1_000_000)
        let (kept, copied) = (try Scratch.path(), try Scratch.path())
        let (keeping, copying) = (
            try SQLite.Database(path: kept, configuration: never), try SQLite.Database(path: copied, configuration: beside)
        )
        defer {
            keeping.close()
            copying.close()
        }
        try await fill(keeping)
        try await fill(copying)
        await copying.checkpointsSettled()
        #expect(try size(kept) <= 8_192)
        #expect(try size(copied) >= 200_000)
    }

    @Test func `at the limit the write that commits copies the log back`() async throws {
        var configuration = SQLite.Configuration()
        configuration.checkpoint = .concurrent(pages: 10, limit: 10)
        let path = try Scratch.path()
        let database = try SQLite.Database(path: path, configuration: configuration)
        defer { database.close() }
        try await fill(database)
        #expect(try size(path) >= 200_000)
    }

    @Test func `a database in memory and one that is read-only take a checkpoint policy and ignore it`() async throws {
        var configuration = SQLite.Configuration()
        configuration.checkpoint = .concurrent(pages: 1, limit: 1)
        let memory = try SQLite.Database(configuration: configuration)
        try await fill(memory)
        memory.close()
        let path = try Scratch.path()
        let made = try SQLite.Database(path: path)
        try await fill(made)
        made.close()
        configuration.readonly = true
        let readonly = try SQLite.Database(path: path, configuration: configuration)
        let count = try await readonly.read { connection throws(ISO.`9075`.Error) in
            try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM entry")
        }
        #expect(count == 100)
        readonly.close()
    }
}
