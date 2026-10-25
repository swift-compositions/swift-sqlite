#if CloudKit && canImport(CloudKit)
    import CloudKit
    import SQL
    import SQLite
    import SQLite_CloudKit
    import Testing

    /// A record's change tag survives its stored representation. Encoded as an integer, the unarchiver refused it as
    /// "not an object", logged a runtime warning for every record read, and dropped the tag.
    @Suite struct `Record representations` {
        static func record() -> CKRecord {
            let record = CKRecord(recordType: "reminders", recordID: CKRecord.ID(recordName: "1:reminders"))
            record._recordChangeTag = 7
            return record
        }

        @Test func `the system fields keep the change tag`() throws {
            let stored = _SystemFieldsRepresentation(queryOutput: Self.record()).queryBinding
            let decoded = try SQLite.Database().read { connection in
                try SQLQueryExpression<_SystemFieldsRepresentation<CKRecord>>("SELECT \(stored)").fetchOne(connection)
            }
            #expect(decoded?._recordChangeTag == 7)
        }

        @Test func `all fields keep the change tag`() throws {
            let stored = _AllFieldsRepresentation(queryOutput: Self.record()).queryBinding
            let decoded = try SQLite.Database().read { connection in
                try SQLQueryExpression<_AllFieldsRepresentation<CKRecord>>("SELECT \(stored)").fetchOne(connection)
            }
            #expect(decoded?._recordChangeTag == 7)
        }
    }
#endif
