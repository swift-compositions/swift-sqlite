#if CloudKit && canImport(CloudKit)
    import CloudKit
    import Foundation
    import ISO_9075_Call_Level_Interface
    import Path
    import SQL
    import SQL_Macros
    import SQLite
    @testable import SQLite_CloudKit
    import SQLite_Test_Support
    import Testing
    import Tests_Inline_Snapshot

    extension CloudKitTestBase {
        @MainActor
        @Suite(.timeLimit(.minutes(5))) struct `Sync engine` {
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
                    userDatabase: UserDatabase(database: try SQLite.Database()),
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

            @Test func `in-memory user databases do not share a metadatabase`() async throws {
                func syncEngine() async throws -> SyncEngine {
                    try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "test",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: try SQLite.Database()),
                        tables: []
                    )
                }
                let first = try await syncEngine()
                let second = try await syncEngine()

                #expect(first.metadatabase.path != second.metadatabase.path)

                try await first.metadatabase.write { db in
                    try #sql(
                        """
                        INSERT INTO "swiftsqlite_icloud_metadata"
                          ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "userModificationTime")
                        VALUES ('1', 'reminders', 'zone', 'owner', 0)
                        """
                    )
                    .execute(db)
                }
                let firstCount = try await first.userDatabase.read { db in
                    try Int.fetchOne(db, sql: #"SELECT count(*) FROM "swiftsqlite_icloud_metadata""#)
                }
                let secondCount = try await second.userDatabase.read { db in
                    try Int.fetchOne(db, sql: #"SELECT count(*) FROM "swiftsqlite_icloud_metadata""#)
                }
                #expect(firstCount == 1)
                #expect(secondCount == 0)
            }

            @Test func `an in-memory user database is rejected in the live context`() async throws {
                let error = await #expect(throws: (any Swift.Error).self) {
                    try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "test",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: try SQLite.Database()),
                        tables: [],
                        context: .live
                    )
                }
                await snapshot(as: .state) {
                    error
                } matches: {
                    """
                    InMemoryDatabase()
                    """
                }
            }

            @Test func `a metadatabase attached for another container is a schema error`() async throws {
                let error = await #expect(throws: SyncEngine.SchemaError.self) {
                    var configuration = SQLite.Configuration()
                    configuration.prepareDatabase { (db: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                        try db.attachMetadatabase(containerIdentifier: "iCloud.org.swiftinstitute")
                    }
                    let path = "/tmp/\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
                    let database = try SQLite.Database(
                        path: try Path::Path(validating: path),
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

    @Test func `a sync engine for a temporary database in the test context`() async throws {
        _ = try await SyncEngine(
            for: SQLite.Database(
                path: Path::Path(
                    validating: URL.temporaryDirectory
                        .appending(path: "\(ProcessInfo.processInfo.globallyUniqueString).db")
                        .path(percentEncoded: false)
                )
            ),
            context: .test
        )
    }

    @Test func `a sync engine for an in-memory database in the preview context`() async throws {
        _ = try await SyncEngine(for: SQLite.Database(), context: .preview)
    }
#endif
