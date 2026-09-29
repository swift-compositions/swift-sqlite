#if CloudKit && DEBUG && canImport(DeveloperToolsSupport)
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Previews`: CloudKitTestBase, @unchecked Sendable {
            init() async throws {
                try await super.init(context: .preview)
            }

            @Test func `changes sync automatically in previews`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                await testClock.advance(by: .seconds(1))
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Personal"
                          )
                        ]
                      ),
                      sharedCloudDatabase: MockCloudDatabase(
                        databaseScope: .shared,
                        storage: []
                      )
                    )
                    """
                }
            }

            @Test func `deleting in a preview`() async throws {
                @FetchAll(database: userDatabase.database) var remindersLists: [RemindersList]

                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }

                await testClock.advance(by: .seconds(1))
                $remindersLists.load(RemindersList.all.selectStar() as Select<RemindersList, RemindersList, ()>, database: userDatabase.database)
                #expect(remindersLists.count == 1)
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Personal"
                          )
                        ]
                      ),
                      sharedCloudDatabase: MockCloudDatabase(
                        databaseScope: .shared,
                        storage: []
                      )
                    )
                    """
                }

                try await userDatabase.userWrite { db in
                    try RemindersList.delete().execute(db)
                }
                $remindersLists.load(RemindersList.all.selectStar() as Select<RemindersList, RemindersList, ()>, database: userDatabase.database)
                #expect(remindersLists.count == 0)

                await testClock.advance(by: .seconds(1))
                $remindersLists.load(RemindersList.all.selectStar() as Select<RemindersList, RemindersList, ()>, database: userDatabase.database)
                #expect(remindersLists.count == 0)
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: []
                      ),
                      sharedCloudDatabase: MockCloudDatabase(
                        databaseScope: .shared,
                        storage: []
                      )
                    )
                    """
                }
            }
        }
    }
#endif

