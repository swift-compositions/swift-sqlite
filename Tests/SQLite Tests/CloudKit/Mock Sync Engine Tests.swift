#if CloudKit
    import CloudKit
    import SQL
    import SQLite
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Mock sync engine`: CloudKitTestBase, @unchecked Sendable {
            @Test func `fetching changes does not mutate database`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 30) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).update { $0.title = "Family" }.execute(db)
                    }
                }

                let before = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                #expect(before.userModificationTime == 0)

                try await syncEngine.private.fetchChanges(CKSyncEngine.FetchChangesOptions())

                let after = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                #expect(after.userModificationTime == 0)
                #expect(after.encryptedValues["title"] as? String == "Personal")

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
            }
        }
    }
#endif
