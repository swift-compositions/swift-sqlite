#if CloudKit
    import CloudKit
    import GRDB
    import SQL
    import SQLite
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Modify records callback`: CloudKitTestBase, @unchecked Sendable {
            @Test func `deferred callback delivers the latest records`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed { RemindersList(id: 1, title: "Original") }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let firstRecord = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                firstRecord.setValue("First", forKey: "title", at: 30_000_000_000)
                let callback = try syncEngine.modifyRecords(scope: .private, saving: [firstRecord])

                let secondRecord = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                secondRecord.setValue("Second", forKey: "title", at: 60_000_000_000)
                _ = try syncEngine.modifyRecords(scope: .private, saving: [secondRecord])

                await callback.notify()

                let title = try await userDatabase.database.read { db in
                    try RemindersList.find(1).select(\.title).fetchOne(db)
                }
                #expect(title == "Second")
            }

            @Test func `deferred callback skips the deletion of a re-saved record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed { RemindersList(id: 1, title: "Original") }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let recordID = RemindersList.recordID(for: 1)

                let callback = try syncEngine.modifyRecords(
                    scope: .private,
                    deleting: [recordID]
                )

                let revivedRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: recordID
                )
                revivedRecord.setValue("Revived", forKey: "title", at: 30_000_000_000)
                _ = try syncEngine.modifyRecords(scope: .private, saving: [revivedRecord])

                await callback.notify()

                let title = try await userDatabase.database.read { db in
                    try RemindersList.find(1).select(\.title).fetchOne(db)
                }
                #expect(title == "Original")
            }
        }
    }
#endif
