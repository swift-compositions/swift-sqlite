#if CloudKit
    import CloudKit
    import Foundation
    import GRDB
    import InlineSnapshotTesting
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    extension CloudKitTestBase {
        @MainActor
        @Suite struct `Sync engine` {
            @Test func `in-memory URLs are detected`() throws {
                #expect(URL(string: "")?.isInMemory == nil)
                #expect(URL(string: ":memory:")?.isInMemory == true)
                #expect(URL(string: ":memory:?cache=shared")?.isInMemory == true)
                #expect(URL(string: "file::memory:")?.isInMemory == true)
                #expect(URL(string: "file:memdb1?mode=memory&cache=shared")?.isInMemory == true)
            }

            @Test func `an in-memory user database attaches the metadatabase`() async throws {
                let syncEngine = try await SyncEngine(
                    container: MockCloudContainer(
                        containerIdentifier: "test",
                        privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                        sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                    ),
                    userDatabase: UserDatabase(database: DatabaseQueue()),
                    tables: []
                )

                try await syncEngine.userDatabase.read { db in
                    try #sql(
                        """
                        SELECT 1 FROM "swiftsqlite_icloud_metadata"
                        """
                    )
                    .execute(db)
                }
            }

            @Test(arguments: [false, true])
            func `the metadatabase inherits the suspension notification configuration`(
                _ observesSuspensionNotifications: Bool
            ) async throws {
                var configuration = Configuration()
                configuration.observesSuspensionNotifications = observesSuspensionNotifications
                let syncEngine = try await SyncEngine(
                    container: MockCloudContainer(
                        containerIdentifier: "test",
                        privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                        sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                    ),
                    userDatabase: UserDatabase(
                        database: try DatabaseQueue(configuration: configuration)
                    ),
                    tables: [],
                    startImmediately: false
                )

                #expect(
                    syncEngine.metadatabase.configuration.observesSuspensionNotifications
                        == observesSuspensionNotifications
                )
            }

            @Test func `an in-memory user database is rejected in the live context`() async throws {
                let error = await #expect(throws: (any Error).self) {
                    try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "test",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: DatabaseQueue()),
                        tables: [],
                        context: .live
                    )
                }
                assertInlineSnapshot(of: error, as: .customDump) {
                    """
                    InMemoryDatabase()
                    """
                }
            }

            @Test func `a metadatabase attached for another container is a schema error`() async throws {
                let error = await #expect(throws: SyncEngine.SchemaError.self) {
                    var configuration = Configuration()
                    configuration.prepareDatabase { db in
                        try db.attachMetadatabase(containerIdentifier: "iCloud.org.swiftinstitute")
                    }
                    let path = "/tmp/\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
                    let database = try DatabasePool(
                        path: path,
                        configuration: configuration
                    )
                    _ = try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "iCloud.org.swift-institute",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: database),
                        tables: []
                    )
                }

                #expect(
                    error?.debugDescription == """
                        Metadatabase attached in 'prepareDatabase' does not match metadatabase prepared in \
                        'SyncEngine.init'. Are different CloudKit container identifiers being provided?
                        """
                )
            }

            #if os(macOS) || os(Linux)
                @Test func `invoking isSynchronizing at trigger creation is a precondition failure`() async throws {
                    let result = await #expect(
                        processExitsWith: .failure,
                        observing: [\.standardErrorContent]
                    ) {
                        _ = Reminder.createTemporaryTrigger(
                            after: .insert { new in
                                Select(SyncEngine.isSynchronizing)
                            }
                        )
                    }
                    #expect(
                        String(decoding: try #require(result).standardErrorContent, as: UTF8.self).contains(
                            """
                            Invoked 'SyncEngine.isSynchronizing' at trigger creation, which is unexpected. Use \
                            'SyncEngine.$isSynchronizing' to invoke at trigger execution, instead.
                            """
                        )
                    )
                    _ = Reminder.createTemporaryTrigger(
                        after: .insert { new in
                            Select(SyncEngine.$isSynchronizing)
                        }
                    )
                }
            #endif
        }
    }

    @Test func `a sync engine for a temporary database in the test context`() throws {
        _ = try SyncEngine(
            for: DatabasePool(
                path: URL.temporaryDirectory
                    .appending(path: "\(ProcessInfo.processInfo.globallyUniqueString).db")
                    .path(percentEncoded: false)
            ),
            context: .test
        )
    }

    @Test func `a sync engine for an in-memory database in the preview context`() throws {
        _ = try SyncEngine(for: DatabaseQueue(), context: .preview)
    }
#endif
