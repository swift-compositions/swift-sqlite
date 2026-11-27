import ISO_9075_Call_Level_Interface
import Order
import SQL
import SQL_Macros
import SQLite
import Testing

@Table
private struct Item {
    var title: String
}

@DatabaseCollation
private func reversed(_ lhs: String, _ rhs: String) -> Order.Comparison {
    Order.Comparison(rhs, lhs)
}

private func items(_ titles: [String] = []) async throws -> SQLite.Database {
    let database = try SQLite.Database()
    try await database.write { connection throws(ISO.`9075`.Error) in
        try #sql(#"CREATE TABLE "item" ("title" TEXT NOT NULL)"#).execute(connection)
        for title in titles {
            try Item.insert { Item(title: title) }.execute(connection)
        }
    }
    return database
}

@Suite(.timeLimit(.minutes(5))) struct `A custom collation` {
    @Test func `orders rows until it is removed`() async throws {
        let database = try await items(["a", "c", "b"])
        try await database.write { connection throws(ISO.`9075`.Error) in connection.add(collation: $reversed) }
        let titles = try await database.read { connection throws(ISO.`9075`.Error) in
            try Item.order { $0.title.collate($reversed) }.fetch.all(connection).map(\.title)
        }
        #expect(titles == ["c", "b", "a"])

        try await database.write { connection throws(ISO.`9075`.Error) in connection.remove(collation: $reversed) }
        await #expect(throws: ISO.`9075`.Error.self) {
            try await database.read { connection throws(ISO.`9075`.Error) in
                _ = try Item.order { $0.title.collate($reversed) }.fetch.all(connection)
            }
        }
    }

    @Test func `the canonical collation orders like Swift strings`() async throws {
        let titles = ["cafe\u{0301}z", "CAFE", "caf\u{00E9}", "caff", "cafe"]
        let database = try await items(titles)
        try await database.write { connection throws(ISO.`9075`.Error) in connection.add(collation: .canonical) }
        let ordered = try await database.read { connection throws(ISO.`9075`.Error) in
            try Item.order { $0.title.collate(.canonical) }.fetch.all(connection).map(\.title)
        }
        #expect(ordered == titles.sorted())
    }

    @Test func `the canonical collation equates canonically equivalent strings`() async throws {
        let database = try await items(["caf\u{00E9}", "cafe\u{0301}", "cafe"])
        try await database.write { connection throws(ISO.`9075`.Error) in connection.add(collation: .canonical) }
        let matches = try await database.read { connection throws(ISO.`9075`.Error) in
            try Item.where { $0.title.collate(.canonical).eq("caf\u{00E9}") }.fetch.all(connection)
        }
        #expect(matches.count == 2)
    }
}
