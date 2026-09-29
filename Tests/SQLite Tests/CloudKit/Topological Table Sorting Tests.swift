#if CloudKit
    import GRDB
    import CloudKit
    import SQLite
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Topological table sorting`: CloudKitTestBase, @unchecked Sendable {
            @Test func `orders the synchronized tables so that parents precede their children`() async throws {
                #expect(
                    syncEngine.tablesByOrder == [
                        "remindersLists": 0,
                        "reminders": 1,
                        "remindersListAssets": 2,
                        "tags": 3,
                        "reminderTags": 4,
                        "parents": 5,
                        "childWithOnDeleteSetNulls": 6,
                        "childWithOnDeleteSetDefaults": 7,
                        "modelAs": 8,
                        "modelBs": 9,
                        "modelCs": 10,
                        "remindersListPrivates": 11,
                    ]
                )
            }
        }
    }
#endif
