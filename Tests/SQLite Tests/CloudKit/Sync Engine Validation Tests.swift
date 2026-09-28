#if CloudKit
    import CloudKit
    import Foundation
    import GRDB
    import InlineSnapshotTesting
    import RFC_4122
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @MainActor
    @Suite struct `Sync engine schema validation` {
        @Table("invalid:table")
        struct InvalidTable {
            let id: RFC_4122.UUID
        }

        @Table struct Child: Identifiable {
            let id: Int
            var parentID: Parent.ID
        }

        @Table struct Parent: Identifiable {
            let id: Int
        }

        @Table struct ModelWithUniqueColumn {
            let id: Int
            let uniqueValue: Int
        }

        @Table struct RecursiveTable: Identifiable {
            let id: Int
            let parentID: RecursiveTable.ID?
        }

        @Test func `rejects a table name containing a colon`() async throws {
            let error = try #require(
                await #expect(throws: (any Error).self) {
                    let database = try DatabaseQueue()
                    _ = try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "deadbeef",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: database),
                        tables: InvalidTable.self
                    )
                }
            )
            assertInlineSnapshot(of: error.localizedDescription, as: .customDump) {
                """
                "Could not synchronize data with iCloud."
                """
            }
            assertInlineSnapshot(of: error, as: .customDump) {
                #"""
                SyncEngine.SchemaError(
                  reason: .invalidTableName("invalid:table"),
                  debugDescription: "Table name contains invalid character \':\'"
                )
                """#
            }
        }

        @Test func `rejects a foreign key with no action on delete`() async throws {
            let error = try #require(
                await #expect(throws: (any Error).self) {
                    let database = try DatabaseQueue()
                    try await database.write { db in
                        try #sql(
                            """
                            CREATE TABLE "parents" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
                            ) STRICT
                            """
                        )
                        .execute(db)
                        try #sql(
                            """
                            CREATE TABLE "childs" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                              "parentID" INTEGER REFERENCES "parents"("id") ON DELETE NO ACTION
                            ) STRICT
                            """
                        )
                        .execute(db)
                    }
                    _ = try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "deadbeef",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: database),
                        tables: Child.self, Parent.self
                    )
                }
            )
            assertInlineSnapshot(of: error.localizedDescription, as: .customDump) {
                """
                "Could not synchronize data with iCloud."
                """
            }
            assertInlineSnapshot(of: error, as: .customDump) {
                """
                SyncEngine.SchemaError(
                  reason: .invalidForeignKeyAction(
                    ForeignKey(
                      table: "parents",
                      from: "parentID",
                      to: "id",
                      onUpdate: .noAction,
                      onDelete: .noAction,
                      isNotNull: false
                    )
                  ),
                  debugDescription: #"Foreign key "childs"."parentID" action not supported. Must be 'CASCADE', 'SET DEFAULT' or 'SET NULL'."#
                )
                """
            }
        }

        @Test func `rejects a foreign key that restricts deletes`() async throws {
            let error = try #require(
                await #expect(throws: (any Error).self) {
                    let database = try DatabaseQueue()
                    try await database.write { db in
                        try #sql(
                            """
                            CREATE TABLE "parents" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
                            ) STRICT
                            """
                        )
                        .execute(db)
                        try #sql(
                            """
                            CREATE TABLE "childs" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                              "parentID" INTEGER REFERENCES "parents"("id") ON DELETE RESTRICT
                            ) STRICT
                            """
                        )
                        .execute(db)
                    }
                    _ = try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "deadbeef",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: database),
                        tables: Parent.self, Child.self
                    )
                }
            )
            assertInlineSnapshot(of: error.localizedDescription, as: .customDump) {
                """
                "Could not synchronize data with iCloud."
                """
            }
            assertInlineSnapshot(of: error, as: .customDump) {
                """
                SyncEngine.SchemaError(
                  reason: .invalidForeignKeyAction(
                    ForeignKey(
                      table: "parents",
                      from: "parentID",
                      to: "id",
                      onUpdate: .noAction,
                      onDelete: .restrict,
                      isNotNull: false
                    )
                  ),
                  debugDescription: #"Foreign key "childs"."parentID" action not supported. Must be 'CASCADE', 'SET DEFAULT' or 'SET NULL'."#
                )
                """
            }
        }

        @Test func `rejects a foreign key to a table that is not synchronized`() async throws {
            let error = try #require(
                await #expect(throws: (any Error).self) {
                    let database = try DatabaseQueue()
                    try await database.write { db in
                        try #sql(
                            """
                            CREATE TABLE "parents" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
                            ) STRICT
                            """
                        )
                        .execute(db)
                        try #sql(
                            """
                            CREATE TABLE "childs" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                              "parentID" INTEGER REFERENCES "parents"("id") ON DELETE CASCADE
                            ) STRICT
                            """
                        )
                        .execute(db)
                    }
                    _ = try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "deadbeef",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: database),
                        tables: Child.self
                    )
                }
            )
            assertInlineSnapshot(of: error.localizedDescription, as: .customDump) {
                """
                "Could not synchronize data with iCloud."
                """
            }
            assertInlineSnapshot(of: error, as: .customDump) {
                """
                SyncEngine.SchemaError(
                  reason: .invalidForeignKey(
                    ForeignKey(
                      table: "parents",
                      from: "parentID",
                      to: "id",
                      onUpdate: .noAction,
                      onDelete: .cascade,
                      isNotNull: false
                    )
                  ),
                  debugDescription: #"Foreign key "childs"."parentID" references table "parents" that is not synchronized. Update 'SyncEngine.init' to synchronize "parents". "#
                )
                """
            }
        }

        @Test func `does not validate triggers on tables that are not synchronized`() async throws {
            let database = try DatabaseQueue(
                path: URL.temporaryDirectory
                    .appending(path: "\(ProcessInfo.processInfo.globallyUniqueString).sqlite")
                    .path()
            )
            try await database.write { db in
                try #sql(
                    """
                    CREATE TABLE "remindersLists" (
                      "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                      "title" TEXT NOT NULL DEFAULT ''
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TRIGGER "non_temporary_trigger"
                    AFTER UPDATE ON "remindersLists"
                    FOR EACH ROW BEGIN
                      SELECT 1;
                    END
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TEMPORARY TRIGGER "temporary_trigger"
                    AFTER UPDATE ON "remindersLists"
                    FOR EACH ROW BEGIN
                      SELECT 1;
                    END
                    """
                )
                .execute(db)
            }
            _ = try await SyncEngine(
                container: MockCloudContainer(
                    containerIdentifier: "deadbeef",
                    privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                    sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                ),
                userDatabase: UserDatabase(database: database),
                tables: []
            )
        }

        @Test func `rejects a uniqueness constraint on a synchronized table`() async throws {
            let error = try #require(
                await #expect(throws: (any Error).self) {
                    let database = try DatabaseQueue()
                    try await database.write { db in
                        try #sql(
                            """
                            CREATE TABLE "modelWithUniqueColumns" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                              "uniqueValue" INTEGER NOT NULL,
                              UNIQUE("uniqueValue")
                            ) STRICT
                            """
                        )
                        .execute(db)
                    }
                    _ = try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "deadbeef",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: database),
                        tables: ModelWithUniqueColumn.self
                    )
                }
            )
            assertInlineSnapshot(of: error.localizedDescription, as: .customDump) {
                """
                "Could not synchronize data with iCloud."
                """
            }
            assertInlineSnapshot(of: error, as: .customDump) {
                """
                SyncEngine.SchemaError(
                  reason: .uniquenessConstraint,
                  debugDescription: "Uniqueness constraints are not supported for synchronized tables."
                )
                """
            }
        }

        @Test func `rejects a table that references itself`() async throws {
            let error = try #require(
                await #expect(throws: (any Error).self) {
                    let database = try DatabaseQueue()
                    try await database.write { db in
                        try #sql(
                            """
                            CREATE TABLE "recursiveTables" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                              "parentID" INTEGER REFERENCES "recursiveTables"("id")
                            ) STRICT
                            """
                        )
                        .execute(db)
                    }
                    _ = try await SyncEngine(
                        container: MockCloudContainer(
                            containerIdentifier: "deadbeef",
                            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                        ),
                        userDatabase: UserDatabase(database: database),
                        tables: RecursiveTable.self
                    )
                }
            )
            assertInlineSnapshot(of: error.localizedDescription, as: .customDump) {
                """
                "Could not synchronize data with iCloud."
                """
            }
            assertInlineSnapshot(of: error, as: .customDump) {
                """
                SyncEngine.SchemaError(
                  reason: .cycleDetected,
                  debugDescription: "Cycles are not currently permitted in schemas, e.g. a table that references itself."
                )
                """
            }
        }
    }
#endif
