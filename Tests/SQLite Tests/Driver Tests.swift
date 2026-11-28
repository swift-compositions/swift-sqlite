import Byte
import Foundation
import ISO_9075_Call_Level_Interface
import Path
import SQLite
import SQLite_Test_Support
import Testing

/// Neither Sendable nor a value: what a body may capture and what it may return.
private final class Tally {
    var count = 0
}

private struct Refused: Swift.Error, Equatable {}

private func thread() -> UInt {
    UInt(bitPattern: ObjectIdentifier(Thread.current).hashValue)
}

private func items(in database: SQLite.Database) async throws -> SQLite.Database {
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)")
    }
    return database
}

private func count(_ database: SQLite.Database) async throws -> Int? {
    try await database.read { connection throws(ISO.`9075`.Error) in
        try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM item")
    }
}

@Suite struct `Driver Tests` {
    @Suite struct Scopes {}
    @Suite struct Threads {}
    @Suite struct Synchronous {}
    @Suite struct Statements {}
    @Suite struct Closing {}
    @Suite struct Failures {}
    @Suite struct Copies {}
}

extension `Driver Tests`.Scopes {
    @Test func `a write commits what its body ran, and a read sees it`() async throws {
        for database in [try SQLite.Database(), try SQLite.Database(path: Scratch.path())] {
            _ = try await items(in: database)
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: ["a"])
            }
            #expect(try await count(database) == 1)
        }
    }

    @Test func `a body captures what is not Sendable and returns what is not Sendable`() async throws {
        let database = try await items(in: SQLite.Database())
        let captured = Tally()
        let returned: Tally = try await database.write { connection throws(ISO.`9075`.Error) in
            captured.count += 1
            let result = Tally()
            try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
            result.count = try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM item") ?? -1
            return result
        }
        returned.count += 100
        #expect(returned.count == 101)
    }

    @Test func `a body's own error comes back as the body's, and the write is rolled back`() async throws {
        for database in [try SQLite.Database(), try SQLite.Database(path: Scratch.path())] {
            _ = try await items(in: database)
            await #expect(throws: ISO.`9075`.Failure<Refused>.body(Refused())) {
                try await database.write { connection throws(Refused) in
                    do throws(ISO.`9075`.Error) {
                        try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
                    } catch {
                        Issue.record(error)
                    }
                    throw Refused()
                }
            }
            #expect(try await count(database) == 0)
        }
    }

    @Test func `a rollback scope leaves the database as it was`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        let inside = try await database.withRollback { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
            return try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM item")
        }
        #expect(inside == 1)
        #expect(try await count(database) == 0)
    }

    @Test func `a read in memory refuses every way to write, and the connection writes again afterwards`() async throws {
        let database = try await items(in: SQLite.Database())
        let writes = [
            "INSERT INTO item (name) VALUES ('a')", "CREATE TABLE other (id INTEGER PRIMARY KEY)", "PRAGMA user_version = 3",
            "DELETE FROM item",
        ]
        for sql in writes {
            for script in [false, true] {
                let error = await #expect(throws: ISO.`9075`.Error.self) {
                    try await database.read { connection throws(ISO.`9075`.Error) in
                        if script { try connection.execute(script: sql) } else { try connection.execute(sql: sql) }
                    }
                }
                #expect(error.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .readonly)
                let synchronous = #expect(throws: ISO.`9075`.Error.self) {
                    try Self.synchronously(database, sql, script: script)
                }
                #expect(synchronous.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .readonly)
            }
        }
        let version = try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(script: "INSERT INTO item (name) VALUES ('b')")
            return try Int.fetchOne(connection, sql: "PRAGMA user_version")
        }
        #expect(version == 0)
        #expect(try await count(database) == 1)
    }

    private static func synchronously(_ database: SQLite.Database, _ sql: String, script: Bool) throws(ISO.`9075`.Error) {
        try database.read { connection throws(ISO.`9075`.Error) in
            if script { try connection.execute(script: sql) } else { try connection.execute(sql: sql) }
        }
    }

    @Test func `a read refuses a write, in memory and in a file`() async throws {
        for database in [try SQLite.Database(), try SQLite.Database(path: Scratch.path())] {
            _ = try await items(in: database)
            let error = await #expect(throws: ISO.`9075`.Error.self) {
                try await database.read { connection throws(ISO.`9075`.Error) in
                    try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
                }
            }
            #expect(error.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .readonly)
            // The connection writes again afterwards.
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('b')")
            }
            #expect(try await count(database) == 1)
        }
    }

    @Test func `a write outside a transaction commits statement by statement, and opens its own transaction`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        await #expect(throws: ISO.`9075`.Failure<Refused>.self) {
            try await database.writeWithoutTransaction { connection throws(Refused) in
                let outside = !connection.isInsideTransaction
                #expect(outside)
                do throws(ISO.`9075`.Error) {
                    try connection.execute(sql: "INSERT INTO item (name) VALUES ('kept')")
                } catch {
                    Issue.record(error)
                }
                do throws(ISO.`9075`.Failure<Refused>) {
                    try connection.transaction { () throws(Refused) in
                        let inside = connection.isInsideTransaction
                        #expect(inside)
                        do throws(ISO.`9075`.Error) {
                            try connection.execute(sql: "INSERT INTO item (name) VALUES ('undone')")
                        } catch {
                            Issue.record(error)
                        }
                        throw Refused()
                    }
                } catch {
                    #expect(error == .body(Refused()))
                }
                throw Refused()
            }
        }
        #expect(try await count(database) == 1)
    }

    @Test func `a savepoint keeps what commits and undoes what rolls back`() async throws {
        let database = try await items(in: SQLite.Database())
        try await database.write { connection throws(ISO.`9075`.Error) in
            do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
                try connection.savepoint { () throws(ISO.`9075`.Error) in
                    try connection.execute(sql: "INSERT INTO item (name) VALUES ('kept')")
                    return .commit
                }
                try connection.savepoint { () throws(ISO.`9075`.Error) in
                    try connection.execute(sql: "INSERT INTO item (name) VALUES ('undone')")
                    return .rollback
                }
            } catch {
                throw error.error
            }
        }
        let names = try await database.read { connection throws(ISO.`9075`.Error) in
            try String.fetchAll(connection, sql: "SELECT name FROM item")
        }
        #expect(names == ["kept"])
    }
}

extension `Driver Tests`.Threads {
    @Test @MainActor func `a write runs off the caller's thread and returns to the caller's actor`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        let caller = thread()
        let writer = try await database.write { _ throws(ISO.`9075`.Error) in thread() }
        MainActor.assertIsolated()
        #expect(writer != caller)
        let again = try await database.write { _ throws(ISO.`9075`.Error) in thread() }
        #expect(again == writer)
    }

    @Test func `reads of a database with a file run on threads that are not the writer's`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        let writer = try await database.write { _ throws(ISO.`9075`.Error) in thread() }
        let readers = try await withThrowingTaskGroup(of: UInt.self) { group in
            for _ in 0..<16 {
                group.addTask { try await database.read { _ throws(ISO.`9075`.Error) in thread() } }
            }
            return try await group.reduce(into: Set<UInt>()) { $0.insert($1) }
        }
        #expect(!readers.contains(writer))
        #expect(readers.count <= 5)
    }

    @Test func `a read does not wait for a write that is running`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        let (entered, signal) = AsyncStream<Void>.makeStream()
        let (release, gate) = (DispatchSemaphore(value: 0), DispatchSemaphore(value: 0))
        _ = gate
        let write = Task {
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('pending')")
                signal.yield()
                release.wait()
            }
        }
        for await _ in entered { break }
        // The write holds its transaction open. The read answers from the last commit.
        #expect(try await count(database) == 0)
        release.signal()
        try await write.value
        #expect(try await count(database) == 1)
    }

    @Test func `two hundred writes at once all commit, each on the writer's thread`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        let threads = try await withThrowingTaskGroup(of: UInt.self) { group in
            for index in 0..<200 {
                group.addTask {
                    try await database.write { connection throws(ISO.`9075`.Error) in
                        try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: ["\(index)"])
                        return thread()
                    }
                }
            }
            return try await group.reduce(into: Set<UInt>()) { $0.insert($1) }
        }
        #expect(threads.count == 1)
        #expect(try await count(database) == 200)
    }

    @Test func `a cancelled task's write is refused as an interrupt, and commits nothing`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        let task = Task {
            try await Task.sleep(for: .seconds(60))
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('never')")
            }
        }
        task.cancel()
        let outcome = await task.result
        #expect(throws: CancellationError.self) { try outcome.get() }

        let cancelled = Task {
            await withTaskCancellationHandler {
                while !Task.isCancelled { await Task.yield() }
            } onCancel: {
            }
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('never')")
            }
        }
        cancelled.cancel()
        let error = await #expect(throws: ISO.`9075`.Error.self) { try await cancelled.value } as ISO.`9075`.Error?
        #expect(error.flatMap(SQLite.Error.Code.init) == .interrupt)
        #expect(error?.state == ISO.`9075`.Diagnostic.State(.interrupt))
        #expect(try await count(database) == 0)
    }

    @Test func `a task cancelled while its statement runs has the statement interrupted and the write rolled back`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        let (entered, signal) = AsyncStream<Void>.makeStream()
        let task = Task {
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('undone')")
                signal.yield()
                // A statement with no end: only an interrupt stops it.
                _ = try Int.fetchOne(
                    connection,
                    sql: "WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n) SELECT COUNT(*) FROM n")
            }
        }
        for await _ in entered { break }
        task.cancel()
        let error = await #expect(throws: ISO.`9075`.Error.self) { try await task.value }
        #expect(error.flatMap(SQLite.Error.Code.init) == .interrupt)
        #expect(try await count(database) == 0)
        // The writer works for the next task.
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO item (name) VALUES ('next')")
        }
        #expect(try await count(database) == 1)
    }

    @Test func `a body that throws CancellationError gets it back as its own error`() async throws {
        let database = try SQLite.Database()
        await #expect(throws: ISO.`9075`.Failure<CancellationError>.self) {
            try await database.write { _ throws(CancellationError) in throw CancellationError() }
        }
    }
}

extension `Driver Tests`.Synchronous {
    @Test func `a synchronous read sees committed work, in memory and in a file`() async throws {
        for database in [try SQLite.Database(), try SQLite.Database(path: Scratch.path())] {
            _ = try await items(in: database)
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
            }
            #expect(Self.count(database) == 1)
        }
    }

    @Test func `a synchronous read runs on the caller's thread`() throws {
        let database = try SQLite.Database(path: Scratch.path())
        let caller = thread()
        let reader = try database.read { _ throws(ISO.`9075`.Error) in thread() }
        #expect(reader == caller)
    }

    @Test func `synchronous reads from many threads at once all answer`() async throws {
        let database = try await items(in: SQLite.Database())
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
        }
        let answers = await withTaskGroup(of: Int?.self) { group in
            for _ in 0..<64 { group.addTask { Self.count(database) } }
            return await group.reduce(into: [Int?]()) { $0.append($1) }
        }
        #expect(answers == Array(repeating: 1, count: 64))
    }

    static func count(_ database: SQLite.Database) -> Int? {
        integer(database, "SELECT COUNT(*) FROM item")
    }

    static func integer(_ database: SQLite.Database, _ sql: String) -> Int? {
        (try? reading(database, sql)) ?? nil
    }

    /// A synchronous read, from a function that is not asynchronous: in one that is, `read` is the asynchronous read.
    static func reading(_ database: SQLite.Database, _ sql: String) throws(ISO.`9075`.Error) -> Int? {
        try database.read { connection throws(ISO.`9075`.Error) in try Int.fetchOne(connection, sql: sql) }
    }
}

extension `Driver Tests`.Statements {
    @Test func `rows that are kept beyond their decode call each keep their own values`() async throws {
        let database = try await items(in: SQLite.Database())
        let rows = try await database.write { connection throws(ISO.`9075`.Error) -> [SQLite.Row] in
            try connection.execute(script: "INSERT INTO item (name) VALUES ('a'); INSERT INTO item (name) VALUES ('b'); INSERT INTO item (name) VALUES ('c')")
            return try SQLite.Row.fetchAll(connection, sql: "SELECT id, name FROM item ORDER BY id")
        }
        #expect(try rows.map { try $0.value(at: 0) } == [.int(1), .int(2), .int(3)])
        #expect(try rows.map { try $0.value(at: 1) } == [.text("a"), .text("b"), .text("c")])
        #expect(throws: ISO.`9075`.Error.self) { try rows[0].value(at: 2) }
    }

    @Test func `a lent row gives text and blobs where SQLite holds them`() async throws {
        let database = try SQLite.Database()
        let read = try await database.write { connection throws(ISO.`9075`.Error) -> [[String]] in
            try connection.execute(
                script: "CREATE TABLE cell (id INTEGER PRIMARY KEY, word TEXT, bytes BLOB); INSERT INTO cell (word, bytes) VALUES ('héllo', x'0102ff'), ('', x''), (NULL, NULL)"
            )
            return try connection.fetchAll("SELECT word, bytes, id FROM cell ORDER BY id") { row throws(ISO.`9075`.Error) in
                var seen: [String] = []
                if let text = try row.text(at: 0) { seen.append("\(String(copying: text)) \(text.count)") } else { seen.append("no text") }
                if let bytes = try row.bytes(at: 1) {
                    var sum = 0
                    for index in bytes.indices { sum += Int(bytes[index].bitPattern) }
                    seen.append("\(bytes.count) bytes, sum \(sum)")
                } else {
                    seen.append("no bytes")
                }
                return seen
            }
        }
        #expect(read == [["héllo 6", "3 bytes, sum 258"], [" 0", "0 bytes, sum 0"], ["no text", "no bytes"]])
    }

    @Test func `a lent row refuses a span of a column that holds another type, and its values stay as they were`() async throws {
        let database = try SQLite.Database()
        let read = try await database.write { connection throws(ISO.`9075`.Error) -> [String] in
            try connection.execute(script: "CREATE TABLE cell (number INTEGER, word TEXT, bytes BLOB); INSERT INTO cell VALUES (7, 'seven', x'07')")
            return try connection.fetchAll("SELECT number, word, bytes FROM cell") { row throws(ISO.`9075`.Error) in
                var seen: [String] = []
                // Each column is asked in every way, in turn: a refusal converts nothing, so every answer stays.
                for index in 0..<3 {
                    let before = try row.value(at: index)
                    do throws(ISO.`9075`.Error) {
                        if let text = try row.text(at: index) { seen.append(String(copying: text)) } else { seen.append("nil") }
                    } catch {
                        seen.append("no text")
                    }
                    do throws(ISO.`9075`.Error) {
                        if let bytes = try row.bytes(at: index) { seen.append("\(bytes.count)") } else { seen.append("nil") }
                    } catch {
                        seen.append("no blob")
                    }
                    do throws(ISO.`9075`.Error) {
                        if let text = try row.text(at: index) { seen.append(String(copying: text)) } else { seen.append("nil") }
                    } catch {
                        seen.append("no text")
                    }
                    seen.append(try row.value(at: index) == before ? "same" : "changed")
                }
                do throws(ISO.`9075`.Error) { _ = try row.text(at: 3) } catch { seen.append("no column") }
                return seen
            }.first ?? []
        }
        #expect(
            read == [
                "no text", "no blob", "no text", "same", "seven", "no blob", "seven", "same", "no text", "1", "no text", "same",
                "no column",
            ])
    }

    @Test func `a fetch inside a fetch of the same statement gets a statement of its own`() async throws {
        let database = try await items(in: SQLite.Database())
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO item (name) VALUES ('a'), ('b')")
        }
        let sizes = try await database.read { connection throws(ISO.`9075`.Error) in
            try connection.fetchAll("SELECT name FROM item") { _ throws(ISO.`9075`.Error) in
                try connection.fetchAll("SELECT name FROM item") { row in SQLite.Row(row) }.count
            }
        }
        #expect(sizes == [2, 2])
    }

    @Test func `a statement prepared before a schema change runs after it`() async throws {
        let database = try await items(in: SQLite.Database(path: Scratch.path()))
        for round in 0..<2 {
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: ["\(round)"])
            }
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "ALTER TABLE item ADD COLUMN extra\(round) TEXT")
            }
        }
        #expect(try await count(database) == 2)
    }

    @Test func `two statements in one execution are refused, and a script runs them`() async throws {
        let database = try await items(in: SQLite.Database())
        let error = await #expect(throws: ISO.`9075`.Error.self) {
            try await database.write { connection throws(ISO.`9075`.Error) in
                _ = try connection.execute("INSERT INTO item (name) VALUES ('a'); INSERT INTO item (name) VALUES ('b')")
            }
        }
        #expect(error.flatMap(SQLite.Error.Code.init) == .misuse)
        #expect(try await count(database) == 0)
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(script: "INSERT INTO item (name) VALUES ('a'); INSERT INTO item (name) VALUES ('b')")
        }
        #expect(try await count(database) == 2)
    }

    @Test func `every connection is prepared as it opens, readers included`() async throws {
        var configuration = SQLite.Configuration()
        configuration.prepareDatabase { connection throws(ISO.`9075`.Error) in
            try connection.execute(script: "PRAGMA cache_size = 1234")
        }
        let database = try SQLite.Database(path: Scratch.path(), configuration: configuration)
        let written = try await database.write { connection throws(ISO.`9075`.Error) in
            try Int.fetchOne(connection, sql: "PRAGMA cache_size")
        }
        let read = try await database.read { connection throws(ISO.`9075`.Error) in
            try Int.fetchOne(connection, sql: "PRAGMA cache_size")
        }
        let direct = `Driver Tests`.Synchronous.integer(database, "PRAGMA cache_size")
        #expect([written, read, direct] == [1234, 1234, 1234])
    }

    @Test func `a database with a file is in WAL mode and enforces foreign keys`() async throws {
        let database = try SQLite.Database(path: Scratch.path())
        let (mode, keys) = try await database.write { connection throws(ISO.`9075`.Error) in
            (try String.fetchOne(connection, sql: "PRAGMA journal_mode"), try Int.fetchOne(connection, sql: "PRAGMA foreign_keys"))
        }
        #expect(mode == "wal")
        #expect(keys == 1)
    }
}

extension `Driver Tests`.Failures {
    @Test func `a constraint violation is a diagnostic with SQLite's extended code`() async throws {
        let database = try await items(in: SQLite.Database())
        let error = await #expect(throws: ISO.`9075`.Error.self) {
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
            }
        }
        #expect(error?.state == .integrityConstraintViolation)
        #expect(error.flatMap(SQLite.Error.Code.init) == .uniqueConstraint)
        #expect(try await count(database) == 0)
    }

    @Test func `a statement that does not parse names itself in the message`() async throws {
        let database = try SQLite.Database()
        let error = await #expect(throws: ISO.`9075`.Error.self) {
            try await database.write { connection throws(ISO.`9075`.Error) in try connection.execute(sql: "SELEKT 1") }
        }
        #expect(error.flatMap(SQLite.Error.Code.init) == .error)
    }

    @Test func `a read-only database with no file is not created`() throws {
        var configuration = SQLite.Configuration()
        configuration.readonly = true
        let path = try Scratch.path()
        let error = #expect(throws: SQLite.Error.self) { try SQLite.Database(path: path, configuration: configuration) }
        #expect(error?.code == .cannotOpen)
        #expect(!FileManager.default.fileExists(atPath: path.string))
    }

    @Test func `a read-only database reads, and refuses a write`() async throws {
        let path = try Scratch.path()
        do {
            let database = try await items(in: SQLite.Database(path: path))
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('a')")
            }
            database.close()
        }
        var configuration = SQLite.Configuration()
        configuration.readonly = true
        let database = try SQLite.Database(path: path, configuration: configuration)
        #expect(try await count(database) == 1)
        #expect(`Driver Tests`.Synchronous.count(database) == 1)
        let error = await #expect(throws: ISO.`9075`.Error.self) {
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('b')")
            }
        }
        #expect(error.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .readonly)
    }
}

extension `Driver Tests`.Closing {
    static func closed(file: Bool) async throws -> SQLite.Database {
        let database = try await items(in: file ? SQLite.Database(path: Scratch.path()) : SQLite.Database())
        _ = try await count(database)
        database.close()
        return database
    }

    @Test(arguments: [true, false])
    func `a read, a write and a synchronous read after close throw misuse`(file: Bool) async throws {
        let database = try await Self.closed(file: file)
        let read = await #expect(throws: ISO.`9075`.Error.self) {
            try await database.read { connection throws(ISO.`9075`.Error) in try Int.fetchOne(connection, sql: "SELECT 1") }
        }
        let write = await #expect(throws: ISO.`9075`.Error.self) {
            try await database.write { connection throws(ISO.`9075`.Error) in try connection.execute(sql: "DELETE FROM item") }
        }
        let bare = await #expect(throws: ISO.`9075`.Error.self) {
            try await database.writeWithoutTransaction { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "DELETE FROM item")
            }
        }
        let direct = #expect(throws: ISO.`9075`.Error.self) { try `Driver Tests`.Synchronous.reading(database, "SELECT 1") }
        for error in [read, write, bare, direct] {
            #expect(error.flatMap(SQLite.Error.Code.init) == .misuse)
            #expect(error.map { "\($0)" }?.contains("Connection is closed") == true)
        }
    }

    @Test(arguments: [true, false])
    func `a copy of the database is closed too, and closing twice does nothing`(file: Bool) async throws {
        let database = try await items(in: file ? SQLite.Database(path: Scratch.path()) : SQLite.Database())
        let copy = database
        database.close()
        database.close()
        await #expect(throws: ISO.`9075`.Error.self) {
            try await copy.read { connection throws(ISO.`9075`.Error) in try Int.fetchOne(connection, sql: "SELECT 1") }
        }
    }

    @Test func `reads and writes that race a close each commit or throw misuse, and none crashes`() async throws {
        for _ in 0..<20 {
            let database = try await items(in: SQLite.Database(path: Scratch.path()))
            await withTaskGroup(of: SQLite.Error.Code?.self) { group in
                for index in 0..<24 {
                    group.addTask {
                        do throws(ISO.`9075`.Error) {
                            if index.isMultiple(of: 3) {
                                try await database.write { connection throws(ISO.`9075`.Error) in
                                    try connection.execute(sql: "INSERT INTO item (name) VALUES (?)", arguments: ["\(index)"])
                                }
                            } else if index.isMultiple(of: 2) {
                                _ = try `Driver Tests`.Synchronous.reading(database, "SELECT COUNT(*) FROM item")
                            } else {
                                _ = try await database.read { connection throws(ISO.`9075`.Error) in
                                    try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM item")
                                }
                            }
                            return nil
                        } catch {
                            return SQLite.Error.Code(error) ?? .error
                        }
                    }
                }
                group.addTask {
                    database.close()
                    return nil
                }
                for await code in group { #expect(code == nil || code == .misuse) }
            }
        }
    }

    @Test func `closing a database with a file leaves no -wal and no -shm file`() async throws {
        let path = try Scratch.path()
        let database = try await items(in: SQLite.Database(path: path))
        _ = try await count(database)
        database.close()
        #expect(!FileManager.default.fileExists(atPath: path.string + "-wal"))
        #expect(!FileManager.default.fileExists(atPath: path.string + "-shm"))
    }
}

extension `Driver Tests`.Copies {
    @Test func `a backup copies every row into the destination, replacing what it held`() async throws {
        for (source, destination) in [
            (try SQLite.Database(), try SQLite.Database(path: Scratch.path())),
            (try SQLite.Database(path: Scratch.path()), try SQLite.Database()),
            (try SQLite.Database(path: Scratch.path()), try SQLite.Database(path: Scratch.path())),
        ] {
            _ = try await items(in: source)
            try await source.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO item (name) VALUES ('a'), ('b'), ('c')")
            }
            try await destination.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "CREATE TABLE other (id INTEGER PRIMARY KEY)")
            }
            try await source.backup(to: destination)
            #expect(try await count(destination) == 3)
            let tables = try await destination.read { connection throws(ISO.`9075`.Error) in
                try String.fetchAll(connection, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
            }
            #expect(tables == ["item"])
        }
    }

    @Test func `a database is not backed up to itself`() async throws {
        let database = try SQLite.Database()
        let error = await #expect(throws: SQLite.Error.self) { try await database.backup(to: database) }
        #expect(error?.code == .misuse)
    }
}
