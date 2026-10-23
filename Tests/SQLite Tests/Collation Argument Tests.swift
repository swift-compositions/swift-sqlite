#if GRDB
    import Order
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    private struct Word {
        var text: String
    }

    @DatabaseCollation
    private func reversedStrings(_ lhs: String, _ rhs: String) -> Order.Comparison {
        Order.Comparison(rhs, lhs)
    }

    @DatabaseCollation
    private func reversedBuffers(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Order.Comparison {
        unsafe Order.Comparison(String(decoding: rhs, as: UTF8.self), String(decoding: lhs, as: UTF8.self))
    }

    @DatabaseCollation
    private func reversedUTF8(_ lhs: UTF8Span, _ rhs: UTF8Span) -> Order.Comparison {
        Order.Comparison(String(copying: rhs), String(copying: lhs))
    }

    @DatabaseCollation
    private func reversedSpans(_ lhs: Span<UInt8>, _ rhs: Span<UInt8>) -> Order.Comparison {
        var left: [UInt8] = []
        var right: [UInt8] = []
        for index in lhs.indices { left.append(lhs[index]) }
        for index in rhs.indices { right.append(rhs[index]) }
        return Order.Comparison(String(decoding: right, as: UTF8.self), String(decoding: left, as: UTF8.self))
    }

    private enum Collations {
        @DatabaseCollation
        static func reversedMember(_ lhs: String, _ rhs: String) -> Order.Comparison {
            Order.Comparison(rhs, lhs)
        }
    }

    private func ordered(by collation: some SQLite::DatabaseCollation) throws -> [String] {
        let queue = try SQLite.Database()
        try queue.write { database in
            try #sql(#"CREATE TABLE "word" ("text" TEXT NOT NULL)"#).execute(database)
            for text in ["a", "c", "b"] {
                try Word.insert { Word(text: text) }.execute(database)
            }
            database.add(collation: collation)
        }
        return try queue.read { database in
            try Word.order { $0.text.collate(collation) }.fetchAll(database).map(\.text)
        }
    }

    @Suite struct `A collation expansion` {
        @Test func `compares String arguments`() throws {
            #expect(try ordered(by: $reversedStrings) == ["c", "b", "a"])
        }

        @Test func `compares raw buffer arguments`() throws {
            #expect(try ordered(by: $reversedBuffers) == ["c", "b", "a"])
        }

        @Test func `compares UTF8Span arguments`() throws {
            #expect(try ordered(by: $reversedUTF8) == ["c", "b", "a"])
        }

        @Test func `compares byte span arguments`() throws {
            #expect(try ordered(by: $reversedSpans) == ["c", "b", "a"])
        }

        @Test func `compares through a static member`() throws {
            #expect(try ordered(by: Collations.$reversedMember) == ["c", "b", "a"])
        }
    }
#endif
