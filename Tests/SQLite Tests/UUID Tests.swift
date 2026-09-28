#if GRDB
    import GRDB
    import RFC_4122
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Suite struct `A UUID column` {
        @Test func `decodes text in any case`() throws {
            let queue = try DatabaseQueue()
            try queue.read { database in
                for text in [
                    "deadbeef-dead-beef-dead-beefdeadbeef",
                    "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
                    "A1b2C3d4-E5f6-7890-aB12-Cd34eF567890",
                    "00000000-0000-0000-0000-000000000000",
                ] {
                    let decoded = try #sql("SELECT \(bind: text)", as: RFC_4122.UUID.self).fetchOne(database)
                    #expect(decoded == (try RFC_4122.UUID(text)), "\(text)")
                }
            }
        }

        @Test func `round-trips a bound value`() throws {
            let uuid = try RFC_4122.UUID("a1b2c3d4-e5f6-7890-ab12-cd34ef567890")
            let queue = try DatabaseQueue()
            let decoded = try queue.read { database in
                try #sql("SELECT \(bind: uuid)", as: RFC_4122.UUID.self).fetchOne(database)
            }
            #expect(decoded == uuid)
        }
    }
#endif
