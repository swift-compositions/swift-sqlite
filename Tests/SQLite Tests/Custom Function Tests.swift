#if GRDB
    import GRDB
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

    private func records() throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.prepareDatabase { database in
            database.add(function: $total)
        }
        let queue = try DatabaseQueue(configuration: configuration)
        try queue.write { database in
            try database.execute(
                sql: #"CREATE TABLE "records" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)"#
            )
            try database.execute(sql: #"INSERT INTO "records" DEFAULT VALUES"#)
            try database.execute(sql: #"INSERT INTO "records" DEFAULT VALUES"#)
            try database.execute(sql: #"INSERT INTO "records" DEFAULT VALUES"#)
        }
        return queue
    }

    private func numbers(count: Int) throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.prepareDatabase { database in
            database.add(function: $total)
            database.add(function: $concatenation)
        }
        let queue = try DatabaseQueue(configuration: configuration)
        try queue.write { database in
            try database.execute(
                sql: #"CREATE TABLE "numbers" ("value" INTEGER NOT NULL, "label" TEXT NOT NULL)"#
            )
            try database.execute(
                sql: """
                    WITH RECURSIVE "sequence"("value") AS (
                      SELECT 1 UNION ALL SELECT "value" + 1 FROM "sequence" WHERE "value" < \(count)
                    )
                    INSERT INTO "numbers" SELECT "value", CAST("value" AS TEXT) FROM "sequence"
                    """
            )
        }
        return queue
    }

    @Suite struct `A custom database function` {
        @Test func `a scalar function is callable until it is removed`() throws {
            var configuration = Configuration()
            configuration.prepareDatabase { database in
                database.add(function: $epoch)
            }
            let queue = try DatabaseQueue(configuration: configuration)
            let instant = try queue.read { database in try Values($epoch()).fetchOne(database) }
            #expect(instant == Time.Instant(secondsSinceUnixEpoch: 0))

            try queue.write { database in database.remove(function: $epoch) }
            #expect(throws: (any Error).self) {
                try queue.read { database in _ = try Values($epoch()).fetchOne(database) }
            }
        }

        @Test func `a scalar function receives its argument`() throws {
            var configuration = Configuration()
            configuration.prepareDatabase { database in
                database.add(function: $exclaim)
            }
            let queue = try DatabaseQueue(configuration: configuration)
            let text = try queue.read { database in try Values($exclaim("Blob")).fetchOne(database) }
            #expect(text == "Blob!")
        }

        @Test func `an aggregate function folds every row`() throws {
            let queue = try records()
            let sum = try queue.read { database in
                try Record.select { $total($0.id) }.fetchOne(database)
            }
            #expect(sum == 6)
        }

        @Test func `an aggregate over ten thousand rows sees every row in order`() throws {
            let queue = try numbers(count: 10_000)
            let (sum, labels) = try queue.read { database in
                (
                    try Number.select { $total($0.value) }.fetchOne(database),
                    try Number.select { $concatenation($0.label, order: $0.value) }.fetchOne(database)
                )
            }
            #expect(sum == 50_005_000)
            #expect(labels == (1...10_000).map(String.init).joined(separator: ","))
        }
    }
#endif
