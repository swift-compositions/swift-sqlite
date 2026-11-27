import ISO_9075_Call_Level_Interface
import RFC_4122
import SQL
import SQL_Macros
import SQLite
import Testing

@Suite(.timeLimit(.minutes(5))) struct `A UUID column` {
    @Test func `decodes text in any case`() async throws {
        let database = try SQLite.Database()
        let texts = [
            "deadbeef-dead-beef-dead-beefdeadbeef",
            "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
            "A1b2C3d4-E5f6-7890-aB12-Cd34eF567890",
            "00000000-0000-0000-0000-000000000000",
        ]
        let decoded = try await database.read { connection throws(ISO.`9075`.Error) in
            var decoded: [IETF.RFC.`4122`.UUID?] = []
            for text in texts {
                decoded.append(try #sql("SELECT \(bind: text)", as: IETF.RFC.`4122`.UUID.self).fetch.one(connection))
            }
            return decoded
        }
        #expect(decoded.count == texts.count)
        for (text, decoded) in zip(texts, decoded) {
            #expect(decoded == (try IETF.RFC.`4122`.UUID(text)), "\(text)")
        }
    }

    @Test func `round-trips a bound value`() async throws {
        let uuid = try IETF.RFC.`4122`.UUID("a1b2c3d4-e5f6-7890-ab12-cd34ef567890")
        let database = try SQLite.Database()
        let decoded = try await database.read { connection throws(ISO.`9075`.Error) in
            try #sql("SELECT \(bind: uuid)", as: IETF.RFC.`4122`.UUID.self).fetch.one(connection)
        }
        #expect(decoded == uuid)
    }
}
