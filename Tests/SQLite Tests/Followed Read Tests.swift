import ISO_9075_Call_Level_Interface
import SQLite
import SQLite_Test_Support
import Testing

private func counters(file: Bool) async throws -> SQLite.Database {
    let database = try file ? SQLite.Database(path: Scratch.path()) : SQLite.Database()
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(script: "CREATE TABLE counter (id INTEGER PRIMARY KEY, value INTEGER NOT NULL); INSERT INTO counter VALUES (1, 0); CREATE TABLE other (id INTEGER PRIMARY KEY)")
    }
    return database
}

private func value(_ connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Int {
    try Int.fetchOne(connection, sql: "SELECT value FROM counter WHERE id = 1") ?? -1
}

private func set(_ database: SQLite.Database, to value: Int) async throws {
    try await database.write { connection throws(ISO.`9075`.Error) in
        try connection.execute(sql: "UPDATE counter SET value = ? WHERE id = 1", arguments: [value])
    }
}

/// What a listener has handled, on the actor that listens.
@MainActor
private final class Seen {
    var values: [Int] = []
    var last: Int { values.last ?? -1 }
}

/// A listener on an actor of its own.
private actor Listener {
    var last = -1
    var count = 0

    func listen(to database: SQLite.Database, started: AsyncStream<Void>.Continuation) async throws {
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        started.yield()
        for try await answer in answers {
            last = answer
            count += 1
        }
    }
}

@Suite struct `Followed Read Tests` {
    @Test(arguments: [true, false]) @MainActor
    func `observe returns with the current answer as its first element`(file: Bool) async throws {
        let database = try await counters(file: file)
        try await set(database, to: 7)
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        var iterator = answers.makeAsyncIterator()
        #expect(try await iterator.next() == 7)
    }

    @Test(arguments: [true, false]) @MainActor
    func `when a write returns, a listener on the main actor has handled its answer`(file: Bool) async throws {
        let database = try await counters(file: file)
        let seen = Seen()
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        let listening = Task { @MainActor in
            for try await answer in answers { seen.values.append(answer) }
        }
        // The listener reads its first answer before the first write: a listener that is behind gets only the latest.
        while seen.values.isEmpty { await Task.yield() }
        for number in 1...500 {
            try await set(database, to: number)
            #expect(seen.last == number)
        }
        listening.cancel()
        // 0, the first answer, then each write once, in order.
        #expect(seen.values == Array(0...500))
    }

    @Test func `when a write returns, listeners on three actors have handled its answer, from writers on no actor`() async throws {
        let database = try await counters(file: true)
        let listeners = [Listener(), Listener(), Listener()]
        let (started, signal) = AsyncStream<Void>.makeStream()
        let tasks = listeners.map { listener in Task { try await listener.listen(to: database, started: signal) } }
        var ready = 0
        for await _ in started {
            ready += 1
            if ready == listeners.count { break }
        }
        var breaks = 0
        for number in 1...300 {
            try await set(database, to: number)
            for listener in listeners where await listener.last != number { breaks += 1 }
        }
        #expect(breaks == 0)
        for task in tasks { task.cancel() }
    }

    @Test @MainActor func `a write that leaves the answer equal yields nothing`() async throws {
        let database = try await counters(file: false)
        let seen = Seen()
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        let listening = Task { @MainActor in
            for try await answer in answers { seen.values.append(answer) }
        }
        // The listener reads its first answer before the first write: a listener that is behind gets only the latest.
        while seen.values.isEmpty { await Task.yield() }
        try await set(database, to: 1)
        try await set(database, to: 1)
        try await database.write { connection throws(ISO.`9075`.Error) in try connection.execute(sql: "INSERT INTO other DEFAULT VALUES") }
        try await set(database, to: 2)
        listening.cancel()
        #expect(seen.values == [0, 1, 2])
    }

    @Test @MainActor func `a write that rolls back yields nothing`() async throws {
        let database = try await counters(file: true)
        let seen = Seen()
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        let listening = Task { @MainActor in
            for try await answer in answers { seen.values.append(answer) }
        }
        // The listener reads its first answer before the first write: a listener that is behind gets only the latest.
        while seen.values.isEmpty { await Task.yield() }
        try await set(database, to: 1)
        _ = try await database.withRollback { connection throws(ISO.`9075`.Error) in
            try connection.execute(sql: "UPDATE counter SET value = 99 WHERE id = 1")
        }
        try await set(database, to: 2)
        listening.cancel()
        #expect(seen.values == [0, 1, 2])
    }

    @Test @MainActor func `a write waits for a listener whose body has suspended, and gets the latest answer to it`() async throws {
        let database = try await counters(file: true)
        let seen = Seen()
        let (gate, open) = AsyncStream<Void>.makeStream()
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        let listening = Task { @MainActor in
            for try await answer in answers {
                seen.values.append(answer)
                // Busy after the first answer: the body suspends until the gate opens.
                if answer == 0 { for await _ in gate { break } }
            }
        }
        while seen.values.isEmpty { await Task.yield() }
        let writing = Task { @MainActor in
            try await set(database, to: 1)
            try await set(database, to: 2)
            return seen.last
        }
        for _ in 0..<200 { await Task.yield() }
        // The first write has not returned: its listener has not read again.
        #expect(seen.values == [0])
        open.yield()
        #expect(try await writing.value == 2)
        listening.cancel()
        #expect(seen.values.last == 2)
    }

    @Test @MainActor func `a write from inside a listener's loop body returns, also when two listeners write in reaction to each other`() async throws {
        let database = try await counters(file: true)
        let first = Seen()
        let second = Seen()
        let one = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        let two = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        let reacting = [
            Task { @MainActor in
                for try await answer in one {
                    first.values.append(answer)
                    if answer < 20 { try await set(database, to: answer + 1) }
                }
            },
            Task { @MainActor in
                for try await answer in two {
                    second.values.append(answer)
                    if answer < 20 { try await set(database, to: answer + 1) }
                }
            },
        ]
        // The two listeners drive the counter up between them. Nothing stops.
        while first.last < 20 || second.last < 20 { await Task.yield() }
        for task in reacting { task.cancel() }
        #expect(first.values == first.values.sorted())
        #expect(second.values == second.values.sorted())
    }

    @Test @MainActor func `a cancelled listener and a listener that is gone do not hold a write back`() async throws {
        let database = try await counters(file: true)
        let (gate, _) = AsyncStream<Void>.makeStream()
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        let entered = Seen()
        let listening = Task { @MainActor in
            for try await answer in answers {
                entered.values.append(answer)
                // Stays in its body until it is cancelled.
                for await _ in gate {}
            }
        }
        while entered.values.isEmpty { await Task.yield() }
        let writing = Task { @MainActor in try await set(database, to: 1) }
        for _ in 0..<100 { await Task.yield() }
        listening.cancel()
        try await writing.value

        do {
            let gone = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
            _ = gone
        }
        try await set(database, to: 2)
    }

    @Test @MainActor func `a failing first read is thrown by observe, and a read that fails later ends the sequence with its error`() async throws {
        let database = try await counters(file: false)
        await #expect(throws: ISO.`9075`.Error.self) {
            _ = try await database.observe { connection throws(ISO.`9075`.Error) in
                try Int.fetchOne(connection, sql: "SELECT value FROM missing")
            }
        }
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) in try value(connection) }
        var iterator = answers.makeAsyncIterator()
        #expect(try await iterator.next() == 0)
        let dropping = Task { @MainActor in
            try await database.write { connection throws(ISO.`9075`.Error) in try connection.execute(script: "DROP TABLE counter") }
        }
        await #expect(throws: ISO.`9075`.Error.self) { _ = try await iterator.next() }
        try await dropping.value
        #expect(try await iterator.next() == nil)
    }

    @Test @MainActor func `a followed read cannot write`() async throws {
        let database = try await counters(file: true)
        let answers = try await database.observe { connection throws(ISO.`9075`.Error) -> Int in
            let now = try value(connection)
            if now > 0 { try connection.execute(sql: "INSERT INTO other DEFAULT VALUES") }
            return now
        }
        var iterator = answers.makeAsyncIterator()
        #expect(try await iterator.next() == 0)
        let writing = Task { @MainActor in try await set(database, to: 1) }
        let error = await #expect(throws: ISO.`9075`.Error.self) { _ = try await iterator.next() }
        #expect(error.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .readonly)
        try await writing.value
    }
}
