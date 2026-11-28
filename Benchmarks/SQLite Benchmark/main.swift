// What the driver's fixed costs are, each as two variants in one run. Run it optimised:
//
//     swift run -c release "SQLite Benchmark"
//
// With names after it, only those groups run: followed, reads, fetches, hops, rows, binds, tail.
//
// It prints one line per variant. It asserts nothing: the numbers are for a reader to compare within one run. A
// variant that loops runs its loop five times and prints the fastest, because other work on the machine slows a run
// and never speeds one up.

import Byte
import Foundation
import ISO_9075_Call_Level_Interface
import Path
import SQL
import SQLite
import SQLite_Test_Support
import Synchronization

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

let batches = 5

/// The fastest of five runs of `body`.
func fastest(_ body: () throws -> Void) rethrows -> Duration {
    var best = Duration.seconds(1_000_000)
    for _ in 0..<batches {
        let start = clock.now
        try body()
        best = min(best, clock.now - start)
    }
    return best
}

/// The fastest of five runs of `body`.
func fastest(_ body: () async throws -> Void) async rethrows -> Duration {
    var best = Duration.seconds(1_000_000)
    for _ in 0..<batches {
        let start = clock.now
        try await body()
        best = min(best, clock.now - start)
    }
    return best
}

func scratch() throws -> Path::Path {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return try Path::Path(validating: folder.appending(path: "store.sqlite").path(percentEncoded: false))
}

// MARK: - Followed reads: a write to a table they read, and to one they do not

/// How often the bodies of the followed reads ran.
final class Runs: Sendable {
    private let count = Atomic<Int>(0)
    func add() { count.add(1, ordering: .relaxed) }
    var value: Int { count.load(ordering: .relaxed) }
}

/// A listener on an actor of its own that follows the number of rows of `followed`.
actor Listener {
    var last = -1

    func listen(to database: SQLite.Database, counting runs: Runs, started: AsyncStream<Void>.Continuation) async throws {
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) -> Int in
            runs.add()
            return try Int.fetchOne(connection, sql: "SELECT count(*) FROM followed") ?? -1
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
    let runs = Runs()
    let (started, signal) = AsyncStream<Void>.makeStream()
    let tasks = listeners.map { listener in Task { try await listener.listen(to: database, counting: runs, started: signal) } }
    var ready = 0
    if count > 0 {
        for await _ in started {
            ready += 1
            if ready == count { break }
        }
    }
    for table in ["other", "followed"] {
        let insert: ISO.`9075`.Fragment = "INSERT INTO \(raw: table) (n) VALUES (\(7))"
        let before = runs.value
        let elapsed = try await fastest {
            for _ in 0..<writes {
                try await database.write { connection throws(ISO.`9075`.Error) in _ = try connection.execute(insert) }
            }
        }
        report(
            "write with \(count) followed reads",
            "to a table they \(table == "other" ? "do not read" : "read") (\((runs.value - before) / batches / writes) rereads a write)",
            operations: writes, elapsed)
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
    var elapsed = try await fastest {
        for _ in 0..<count {
            _ = try await database.read { connection throws(ISO.`9075`.Error) in try one(connection) }
        }
    }
    report("one-row read", "await read (a hop to the reader's thread)", operations: count, elapsed)

    try synchronousReads(count, in: database)

    elapsed = try await fastest {
        for _ in 0..<count {
            try await database.write { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in }
        }
    }
    report("one-row read", "await write, empty body", operations: count, elapsed)
    database.close()
}

let selectOne: ISO.`9075`.Fragment = "SELECT n FROM item WHERE id = 1"

/// The one row's value, with no decoder between the driver and the caller.
func one(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Int {
    var total = 0
    _ = try connection.fetchAll(selectOne) { row throws(ISO.`9075`.Error) -> Void in
        if case .int(let n) = try row.value(at: 0) { total &+= Int(n) }
    }
    return total
}

/// In a function that is not asynchronous, so that `read` is the synchronous one.
func synchronousReads(_ count: Int, in database: SQLite.Database) throws {
    var elapsed = try fastest {
        for _ in 0..<count {
            _ = try database.read { connection throws(ISO.`9075`.Error) in try one(connection) }
        }
    }
    report("one-row read", "synchronous read (the caller's thread)", operations: count, elapsed)

    elapsed = try fastest {
        for _ in 0..<count {
            try database.read { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in }
        }
    }
    report("one-row read", "synchronous read, empty body (begin and commit only)", operations: count, elapsed)
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

// MARK: - Fetches in one scope: what one more fetch costs

/// In a function that is not asynchronous, so that `read` is the synchronous one.
func fetches(_ count: Int, in database: SQLite.Database, _ kind: String) throws {
    for each in [0, 1, 2, 10, 100] {
        let elapsed = try fastest {
            for _ in 0..<count {
                _ = try database.read { connection throws(ISO.`9075`.Error) -> Int in
                    var total = 0
                    for _ in 0..<each { total &+= try one(connection) }
                    return total
                }
            }
        }
        report("synchronous read, \(kind)", "\(each) fetches in the scope", operations: count, elapsed)
    }
    // The same fetch through the typed layer, and through the test support's helper that parses its text.
    let typed = try fastest {
        for _ in 0..<count {
            _ = try database.read { connection throws(ISO.`9075`.Error) -> Int in
                var total = 0
                for _ in 0..<100 { total &+= try SQLQueryExpression<Int>(selectOne).fetch.one(connection) ?? 0 }
                return total
            }
        }
    }
    report("synchronous read, \(kind)", "100 fetches decoded as Int", operations: count, typed)
    let text = try fastest {
        for _ in 0..<count {
            _ = try database.read { connection throws(ISO.`9075`.Error) -> Int in
                var total = 0
                for _ in 0..<100 { total &+= try Int.fetchOne(connection, sql: "SELECT n FROM item WHERE id = 1") ?? 0 }
                return total
            }
        }
    }
    report("synchronous read, \(kind)", "100 fetches from text, decoded as Int", operations: count, text)
}

func fetchCosts(_ count: Int) async throws {
    for (kind, database) in [("file", try SQLite.Database(path: scratch())), ("memory", try SQLite.Database())] {
        try await database.write { connection throws(ISO.`9075`.Error) in
            try connection.execute(script: "CREATE TABLE item (id INTEGER PRIMARY KEY, n INTEGER NOT NULL); INSERT INTO item VALUES (1, 7)")
        }
        try fetches(count, in: database, kind)
        database.close()
    }
}

// MARK: - The hop: the way out, the body, and the way back

struct Stamps: Sendable {
    var out = Duration.zero
    var body = Duration.zero
    var back = Duration.zero
    var whole: Duration { out + body + back }

    mutating func add(_ before: ContinuousClock.Instant, _ inside: (ContinuousClock.Instant, ContinuousClock.Instant)) {
        let after = clock.now
        out += inside.0 - before
        body += inside.1 - inside.0
        back += after - inside.1
    }
}

func hops(_ count: Int, in database: SQLite.Database, write: Bool, fetching: Bool = false) async throws -> Stamps {
    var best = Stamps()
    for batch in 0..<batches {
        var stamps = Stamps()
        for _ in 0..<count {
            let before = clock.now
            let inside: (ContinuousClock.Instant, ContinuousClock.Instant)
            if write {
                inside = try await database.write { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                    let start = clock.now
                    return (start, clock.now)
                }
            } else {
                inside = try await database.read { (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                    let start = clock.now
                    if fetching { _ = try one(connection) }
                    return (start, clock.now)
                }
            }
            stamps.add(before, inside)
        }
        if batch == 0 || stamps.whole < best.whole { best = stamps }
    }
    return best
}

@MainActor func hopsOnMain(_ count: Int, in database: SQLite.Database, write: Bool) async throws -> Stamps {
    try await hops(count, in: database, write: write)
}

@concurrent func hopsOnPool(_ count: Int, in database: SQLite.Database, write: Bool, fetching: Bool = false) async throws -> Stamps {
    try await hops(count, in: database, write: write, fetching: fetching)
}

/// An actor on the cooperative pool that counts.
actor Pooled {
    var count = 0
    func work(_ rounds: Int) -> Int {
        for round in 0..<rounds { count = (count &* 31) &+ round }
        count &+= 1
        return count
    }
}

/// How many rounds of the actors' loop take about as long as one small read: 3 µs.
func roundsOfThreeMicroseconds() -> Int {
    var count = 0
    let start = clock.now
    for round in 0..<10_000_000 { count = (count &* 31) &+ round }
    let each = (clock.now - start) / 10_000_000
    precondition(count != 1)
    return max(1, Int(Duration.microseconds(3) / each))
}

@concurrent func bareHops(_ count: Int) async {
    let rounds = roundsOfThreeMicroseconds()
    let idle = Idle()
    let pooled = Pooled()
    for (work, name) in [(0, "that does nothing"), (rounds, "that works for 3 µs")] {
        var total = 0
        var elapsed = await fastest { for _ in 0..<count { total &+= await idle.work(work) } }
        report("a call \(name)", "to an actor on a thread of its own, from the pool", operations: count, elapsed)
        elapsed = await fastest { for _ in 0..<count { total &+= await pooled.work(work) } }
        report("a call \(name)", "to an actor on the pool, from the pool", operations: count, elapsed)
        precondition(total != 1)
    }
}

func hopCosts(_ count: Int) async throws {
    await bareHops(count)
    let database = try SQLite.Database(path: scratch())
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(script: "CREATE TABLE item (id INTEGER PRIMARY KEY, n INTEGER NOT NULL); INSERT INTO item VALUES (1, 7)")
    }
    let fetching = try await hopsOnPool(count, in: database, write: false, fetching: true)
    report("await read of one row", "from the pool, whole call", operations: count, fetching.whole)
    report("await read of one row", "from the pool, the way out", operations: count, fetching.out)
    report("await read of one row", "from the pool, the fetch", operations: count, fetching.body)
    report("await read of one row", "from the pool, commit and the way back", operations: count, fetching.back)
    for write in [false, true] {
        let name = "empty await \(write ? "write" : "read")"
        for caller in ["the main actor", "the pool"] {
            let stamps = caller == "the pool"
                ? try await hopsOnPool(count, in: database, write: write)
                : try await hopsOnMain(count, in: database, write: write)
            report(name, "from \(caller), whole call", operations: count, stamps.whole)
            report(name, "from \(caller), the way out\(write ? " and the begin" : "")", operations: count, stamps.out)
            report(name, "from \(caller), commit and the way back", operations: count, stamps.back)
        }
        let elapsed = try await fastest {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<8 {
                    group.addTask {
                        for _ in 0..<(count / 8) {
                            if write {
                                try await database.write { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in }
                            } else {
                                try await database.read { (_: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in }
                            }
                        }
                    }
                }
                try await group.waitForAll()
            }
        }
        report(name, "from 8 tasks on the pool at once, whole call", operations: count, elapsed)
    }
    database.close()
}

// MARK: - Run

let chosen = Set(CommandLine.arguments.dropFirst())
func runs(_ name: String) -> Bool { chosen.isEmpty || chosen.contains(name) }

if runs("followed") {
    try await followedReads(listeners: 0, writes: 2_000)
    try await followedReads(listeners: 20, writes: 2_000)
}
if runs("reads") { try await smallReads(20_000) }
if runs("fetches") { try await fetchCosts(20_000) }
if runs("hops") { try await hopCosts(20_000) }
if runs("rows") { try await rows(100_000) }
if runs("binds") { try await binds() }
if runs("tail") { try await writeTail(5_000) }
