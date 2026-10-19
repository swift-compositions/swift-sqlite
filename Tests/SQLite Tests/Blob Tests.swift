#if GRDB
    import Byte
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    private struct Attachment {
        var payload: [Byte] = []
    }

    @Suite struct `A blob` {
        let queue: DatabaseQueue

        init() throws {
            queue = try DatabaseQueue()
            try queue.write { database in
                try database.execute(sql: #"CREATE TABLE "attachment" ("payload" BLOB NOT NULL)"#)
            }
        }

        @Test func `Byte is laid out exactly like UInt8`() {
            #expect(MemoryLayout<Byte>.size == MemoryLayout<UInt8>.size)
            #expect(MemoryLayout<Byte>.stride == MemoryLayout<UInt8>.stride)
            #expect(MemoryLayout<Byte>.alignment == MemoryLayout<UInt8>.alignment)
        }

        @Test func `a multi-megabyte blob is bound and decoded in bulk`() throws {
            let payload = (0..<(16 << 20)).map { Byte(bitPattern: UInt8(truncatingIfNeeded: $0 &* 31 &+ 7)) }
            var fetched: [[Byte]] = []
            let elapsed = try ContinuousClock().measure {
                try queue.write { database in
                    try Attachment.insert { Attachment(payload: payload) }.execute(database)
                }
                fetched = try queue.read { database in
                    try Attachment.all.select(\.payload).fetchAll(database)
                }
            }
            #expect(fetched == [payload])
            // A per-byte conversion took tens of seconds for this size in a debug
            // build; the bulk path takes a small fraction of a second.
            #expect(elapsed < .seconds(3))
        }
    }
#endif
