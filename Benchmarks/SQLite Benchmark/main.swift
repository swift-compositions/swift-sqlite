// What the driver's fixed costs are, each as two variants in one run. Run it optimised:
//
//     swift run -c release "SQLite Benchmark"
//
// It prints one line per variant. It asserts nothing: the numbers are for a reader to compare within one run.

import Byte
import Foundation
import ISO_9075_Call_Level_Interface
import Path
import SQL
import SQLite
import SQLite_Test_Support

// MARK: - Measuring

let clock = ContinuousClock()

func report(_ name: String, _ variant: String, operations: Int, _ elapsed: Duration) {
    let nanoseconds = Double(elapsed.components.seconds) * 1e9 + Double(elapsed.components.attoseconds) / 1e9
    let each = nanoseconds / Double(operations)
    let unit = each >= 1_000_000 ? "\((each / 1_000_000).formatted(.number.precision(.fractionLength(2)))) ms"
        : each >= 1_000 ? "\((each / 1_000).formatted(.number.precision(.fractionLength(2)))) µs"
        : "\(each.formatted(.number.precision(.fractionLength(0)))) ns"
    print("\(name) | \(variant) | \(operations) operations | \(unit) each")
}

func scratch() throws -> Path::Path {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return try Path::Path(validating: folder.appending(path: "store.sqlite").path(percentEncoded: false))
}

// MARK: - Followed reads: a write to a table they read, and to one they do not

/// A listener on an actor of its own that follows the number of rows of `followed`.
actor Listener {
    var last = -1

    func listen(to database: SQLite.Database, started: AsyncStream<Void>.Continuation) async throws {
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) -> Int in
            try Int.fetchOne(connection, sql: "SELECT count(*) FROM followed") ?? -1
        }
        started.yield()
        for try await answer in answers { last = answer }
    }
}

func followedReads(listeners count: Int, writes: Int) async throws {
    let database = try SQLite.Database(path: scratch())
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(
            script: "CREATE TABLE followed (id INTEGER PRIMARY KEY, n INTEGER NOT NULL); CREATE TABLE other (id INTEGER PRIMARY KEY, n INTEGER NOT NULL)"
        )
    }
    let listeners = (0..<count).map { _ in Listener() }
    let (started, signal) = AsyncStream<Void>.makeStream()
    let tasks = listeners.map { listener in Task { try await listener.listen(to: database, started: signal) } }
    var ready = 0
    if count > 0 {
        for await _ in started {
            ready += 1
            if ready == count { break }
        }
    }
    for table in ["other", "followed"] {
        let start = clock.now
        for number in 0..<writes {
            try await database.write { connection throws(ISO.`9075`.Error) in
                try connection.execute(sql: "INSERT INTO \(table) (n) VALUES (?)", arguments: [number])
            }
        }
        report("write with \(count) followed reads", "to a table they \(table == "other" ? "do not read" : "read")", operations: writes, clock.now - start)
    }
    for task in tasks { task.cancel() }
    database.close()
}

// MARK: - One small read: asynchronous, synchronous, and an empty scope

func smallReads(_ count: Int) async throws {
    let database = try SQLite.Database(path: scratch())
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(script: "CREATE TABLE item (id INTEGER PRIMARY KEY, n INTEGER NOT NULL); INSERT INTO item VALUES (1, 7)")
    }
    var start = clock.now
    for _ in 0..<count {
        _ = try await database.read { connection throws(ISO.`9075`.Error) in
            try Int.fetchOne(connection, sql: "SELECT n FROM item WHERE id = 1")
        }
    }
    report("one-row read", "await read (a hop to the reader's thread)", operations: count, clock.now - start)

    try synchronousReads(count, in: database)

    start = clock.now
    for _ in 0..<count {
        try await database.write { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in }
    }
    report("one-row read", "await write, empty body", operations: count, clock.now - start)
    database.close()
}

/// In a function that is not asynchronous, so that `read` is the synchronous one.
func synchronousReads(_ count: Int, in database: SQLite.Database) throws {
    var start = clock.now
    for _ in 0..<count {
        _ = try database.read { connection throws(ISO.`9075`.Error) in
            try Int.fetchOne(connection, sql: "SELECT n FROM item WHERE id = 1")
        }
    }
    report("one-row read", "synchronous read (the caller's thread)", operations: count, clock.now - start)

    start = clock.now
    for _ in 0..<count {
        try database.read { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in }
    }
    report("one-row read", "synchronous read, empty body (begin and commit only)", operations: count, clock.now - start)
}

// MARK: - Rows: every column read, and one column read

func rows(_ count: Int) async throws {
    let database = try SQLite.Database(path: scratch())
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(
            script: "CREATE TABLE wide (id INTEGER PRIMARY KEY, a TEXT, b TEXT, c TEXT, d INTEGER, e REAL, f TEXT, g TEXT)"
        )
        for number in 0..<count {
            try connection.execute(
                sql: "INSERT INTO wide (a, b, c, d, e, f, g) VALUES (?, ?, ?, ?, ?, ?, ?)",
                arguments: [
                    "name \(number)", "a longer piece of text for row \(number), as a title would be", "c\(number)",
                    number, Double(number) / 3, "f\(number)", "g\(number)",
                ]
            )
        }
    }
    try readRows(count, in: database)
    database.close()
}

/// In a function that is not asynchronous, so that `read` is the synchronous one.
func readRows(_ count: Int, in database: SQLite.Database) throws {
    let select: ISO.`9075`.Fragment = "SELECT id, a, b, c, d, e, f, g FROM wide"
    for columns in [8, 1] {
        let start = clock.now
        let total = try database.read { connection throws(ISO.`9075`.Error) -> Int in
            var total = 0
            _ = try connection.fetchAll(select) { row throws(ISO.`9075`.Error) -> Void in
                for index in 0..<columns {
                    if case .text(let text) = try row.value(at: index) { total &+= text.utf8.count }
                }
            }
            return total
        }
        report("\(count) rows of 8 columns", "\(columns) column\(columns == 1 ? "" : "s") read (\(total))", operations: count, clock.now - start)
    }
    let start = clock.now
    let kept = try database.read { connection throws(ISO.`9075`.Error) -> Int in
        try connection.fetchAll(select) { $0 }.count
    }
    report("\(count) rows of 8 columns", "every row kept (\(kept))", operations: count, clock.now - start)
}

// MARK: - Binds: text and blobs

func binds() async throws {
    let database = try SQLite.Database(path: scratch())
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(script: "CREATE TABLE text (id INTEGER PRIMARY KEY, body TEXT); CREATE TABLE blob (id INTEGER PRIMARY KEY, body BLOB)")
    }
    let text = String(repeating: "x", count: 1_024)
    var start = clock.now
    try await database.write { connection throws(ISO.`9075`.Error) in
        for _ in 0..<20_000 { try connection.execute(sql: "INSERT INTO text (body) VALUES (?)", arguments: [text]) }
    }
    report("insert in one transaction", "1 KB of text", operations: 20_000, clock.now - start)

    let blob = [Byte](repeating: Byte(bitPattern: 7), count: 1 << 20)
    start = clock.now
    try await database.write { connection throws(ISO.`9075`.Error) in
        for _ in 0..<200 { try connection.execute(sql: "INSERT INTO blob (body) VALUES (?)", arguments: [blob]) }
    }
    report("insert in one transaction", "1 MB blob", operations: 200, clock.now - start)
    database.close()
}

// MARK: - The slowest write: where a checkpoint falls

func writeTail(_ count: Int) async throws {
    let database = try SQLite.Database(path: scratch())
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(script: "CREATE TABLE entry (id INTEGER PRIMARY KEY, body TEXT)")
    }
    let body = String(repeating: "y", count: 2_048)
    var each: [Duration] = []
    each.reserveCapacity(count)
    for _ in 0..<count {
        let start = clock.now
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "INSERT INTO entry (body) VALUES (?)", arguments: [body])
        }
        each.append(clock.now - start)
    }
    each.sort()
    report("\(count) writes of 2 KB, one transaction each", "median", operations: 1, each[count / 2])
    report("\(count) writes of 2 KB, one transaction each", "99th percentile", operations: 1, each[count * 99 / 100])
    report("\(count) writes of 2 KB, one transaction each", "slowest", operations: 1, each[count - 1])
    database.close()
}

// MARK: - Run

try await followedReads(listeners: 0, writes: 2_000)
try await followedReads(listeners: 20, writes: 2_000)
try await smallReads(20_000)
try await rows(100_000)
try await binds()
try await writeTail(5_000)
