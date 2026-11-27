import ISO_9075_Call_Level_Interface
import SQL
import SQL_Macros
import SQLite
import Testing
import Time

@Table
private struct Record {
    let id: Int
}

@Table
private struct Number {
    let value: Int
    var label: String
}

@DatabaseFunction
private func epoch() -> Time.Instant {
    Time.Instant(secondsSinceUnixEpoch: 0)
}

@DatabaseFunction
private func exclaim(_ text: String) -> String {
    text + "!"
}

@DatabaseFunction
private func total(_ values: some Sequence<Int>) -> Int {
    values.reduce(0, +)
}

@DatabaseFunction
private func concatenation(_ labels: some Sequence<String>) -> String {
    labels.joined(separator: ",")
}

private func records() async throws -> SQLite.Database {
    var configuration = SQLite.Configuration()
    configuration.prepareDatabase { connection throws(ISO.`9075`.Error) in
        connection.add(function: $total)
    }
    let database = try SQLite.Database(configuration: configuration)
    try await database.write { connection throws(ISO.`9075`.Error) in
        try #sql(
            #"CREATE TABLE "record" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)"#
        )
        .execute(connection)
        try #sql(#"INSERT INTO "record" DEFAULT VALUES"#).execute(connection)
        try #sql(#"INSERT INTO "record" DEFAULT VALUES"#).execute(connection)
        try #sql(#"INSERT INTO "record" DEFAULT VALUES"#).execute(connection)
    }
    return database
}

private func numbers(count: Int) async throws -> SQLite.Database {
    var configuration = SQLite.Configuration()
    configuration.prepareDatabase { connection throws(ISO.`9075`.Error) in
        connection.add(function: $total)
        connection.add(function: $concatenation)
    }
    let database = try SQLite.Database(configuration: configuration)
    try await database.write { connection throws(ISO.`9075`.Error) in
        try #sql(
            #"CREATE TABLE "number" ("value" INTEGER NOT NULL, "label" TEXT NOT NULL)"#
        )
        .execute(connection)
        try #sql(
            """
            WITH RECURSIVE "sequence"("value") AS (
              SELECT 1 UNION ALL SELECT "value" + 1 FROM "sequence" WHERE "value" < \(count)
            )
            INSERT INTO "number" SELECT "value", CAST("value" AS TEXT) FROM "sequence"
            """
        )
        .execute(connection)
    }
    return database
}

@Suite(.timeLimit(.minutes(5))) struct `A custom database function` {
    @Test func `a scalar function is callable until it is removed`() async throws {
        var configuration = SQLite.Configuration()
        configuration.prepareDatabase { connection throws(ISO.`9075`.Error) in
            connection.add(function: $epoch)
        }
        let database = try SQLite.Database(configuration: configuration)
        let instant = try await database.read { connection throws(ISO.`9075`.Error) in
            try Select($epoch()).fetch.one(connection)
        }
        #expect(instant == Time.Instant(secondsSinceUnixEpoch: 0))

        try await database.write { connection throws(ISO.`9075`.Error) in connection.remove(function: $epoch) }
        await #expect(throws: ISO.`9075`.Error.self) {
            try await database.read { connection throws(ISO.`9075`.Error) in
                _ = try Select($epoch()).fetch.one(connection)
            }
        }
    }

    @Test func `a scalar function receives its argument`() async throws {
        var configuration = SQLite.Configuration()
        configuration.prepareDatabase { connection throws(ISO.`9075`.Error) in
            connection.add(function: $exclaim)
        }
        let database = try SQLite.Database(configuration: configuration)
        let text = try await database.read { connection throws(ISO.`9075`.Error) in
            try Select($exclaim("Blob")).fetch.one(connection)
        }
        #expect(text == "Blob!")
    }

    @Test func `an aggregate function folds every row`() async throws {
        let database = try await records()
        let sum = try await database.read { connection throws(ISO.`9075`.Error) in
            try Record.select { $total($0.id) }.fetch.one(connection)
        }
        #expect(sum == 6)
    }

    @Test func `an aggregate over ten thousand rows sees every row in order`() async throws {
        let database = try await numbers(count: 10_000)
        let (sum, labels) = try await database.read { connection throws(ISO.`9075`.Error) in
            (
                try Number.select { $total($0.value) }.fetch.one(connection),
                try Number.select { $concatenation($0.label, order: $0.value) }.fetch.one(connection)
            )
        }
        #expect(sum == 50_005_000)
        #expect(labels == (1...10_000).map(String.init).joined(separator: ","))
    }
}
