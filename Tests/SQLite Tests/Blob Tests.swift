import Byte
import ISO_9075_Call_Level_Interface
import SQL
import SQL_Macros
import SQLite
import Testing

@Table
private struct Attachment {
    var payload: [Byte] = []
}

@Suite(.timeLimit(.minutes(5))) struct `A blob` {
    let database: SQLite.Database

    init() async throws {
        database = try SQLite.Database()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try #sql(#"CREATE TABLE "attachment" ("payload" BLOB NOT NULL)"#).execute(connection)
        }
    }

    @Test func `Byte is laid out exactly like UInt8`() {
        #expect(MemoryLayout<Byte>.size == MemoryLayout<UInt8>.size)
        #expect(MemoryLayout<Byte>.stride == MemoryLayout<UInt8>.stride)
        #expect(MemoryLayout<Byte>.alignment == MemoryLayout<UInt8>.alignment)
    }

    @Test func `a multi-megabyte blob is bound and decoded in bulk`() async throws {
        let payload = (0..<(16 << 20)).map { Byte(bitPattern: UInt8(truncatingIfNeeded: $0 &* 31 &+ 7)) }
        let clock = ContinuousClock()
        let start = clock.now
        try await database.write { connection throws(ISO.`9075`.Error) in
            try Attachment.insert { Attachment(payload: payload) }.execute(connection)
        }
        let fetched = try await database.read { connection throws(ISO.`9075`.Error) in
            try Attachment.all.select(\.payload).fetch.all(connection)
        }
        let elapsed = clock.now - start
        #expect(fetched == [payload])
        // A per-byte conversion took tens of seconds for this size in a debug
        // build; the bulk path takes a small fraction of a second.
        #expect(elapsed < .seconds(3))
    }
}
