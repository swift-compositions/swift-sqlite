#if GRDB
    import Comparison
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    private struct Item {
        var title: String
    }

    @DatabaseCollation
    private func reversed(_ lhs: String, _ rhs: String) -> Comparison {
        Comparison(comparing: rhs, to: lhs)
    }

    private func items(_ titles: [String] = []) throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try queue.write { database in
            try database.execute(sql: #"CREATE TABLE "items" ("title" TEXT NOT NULL)"#)
            for title in titles {
                try Item.insert { Item(title: title) }.execute(database)
            }
        }
        return queue
    }

    @Suite struct `A custom collation` {
        @Test func `orders rows until it is removed`() throws {
            let queue = try items(["a", "c", "b"])
            try queue.write { database in database.add(collation: $reversed) }
            let titles = try queue.read { database in
                try Item.order { $0.title.collate($reversed) }.fetchAll(database).map(\.title)
            }
            #expect(titles == ["c", "b", "a"])

            try queue.write { database in database.remove(collation: $reversed) }
            #expect(throws: (any Error).self) {
                try queue.read { database in
                    _ = try Item.order { $0.title.collate($reversed) }.fetchAll(database)
                }
            }
        }

        @Test func `the canonical collation orders like Swift strings`() throws {
            let titles = ["cafe\u{0301}z", "CAFE", "caf\u{00E9}", "caff", "cafe"]
            let queue = try items(titles)
            try queue.write { database in database.add(collation: .canonical) }
            let ordered = try queue.read { database in
                try Item.order { $0.title.collate(.canonical) }.fetchAll(database).map(\.title)
            }
            #expect(ordered == titles.sorted())
        }

        @Test func `the canonical collation equates canonically equivalent strings`() throws {
            let queue = try items(["caf\u{00E9}", "cafe\u{0301}", "cafe"])
            try queue.write { database in database.add(collation: .canonical) }
            let matches = try queue.read { database in
                try Item.where { $0.title.collate(.canonical).eq("caf\u{00E9}") }.fetchAll(database)
            }
            #expect(matches.count == 2)
        }
    }
#endif
