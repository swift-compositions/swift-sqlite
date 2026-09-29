#if CloudKit
    import Synchronization
    import CloudKit
    import Foundation
    import GRDB
    import OSLog
    import RFC_4122
    import SQL
    public import SQLite
    import Testing

    @Suite
    class CloudKitTestBase: @unchecked Sendable {
        let userDatabase: UserDatabase
        let container: MockCloudContainer
        let syncEngine: SyncEngine
        let inMemoryDataManager: InMemoryDataManager
        let notificationCenter: NotificationCenter
        let testClock: ManualClock
        let time: ManualTime
        let uuid: IncrementingUUID

        var now: Int64 {
            time.nanoseconds
        }

        init(
            accountStatus: CKAccountStatus = .available,
            attachMetadatabase: Bool = false,
            startImmediately: Bool = true,
            context: SyncEngine.Context = .test,
            delegate: (any SyncEngineDelegate)? = nil,
            prepareDatabase: @Sendable (UserDatabase) async throws -> Void = { _ in }
        ) async throws {
            let containerIdentifier =
                "iCloud.org.swift-institute.SQLite.Testing.\(ProcessInfo.processInfo.globallyUniqueString)"
            let dataManager = InMemoryDataManager()
            dataManager.register()
            let userDatabase = UserDatabase(
                database: try cloudKitTestDatabase(
                    containerIdentifier: containerIdentifier,
                    attachMetadatabase: attachMetadatabase
                )
            )
            try await prepareDatabase(userDatabase)
            let privateDatabase = MockCloudDatabase(databaseScope: .private, dataManager: dataManager)
            let sharedDatabase = MockCloudDatabase(databaseScope: .shared, dataManager: dataManager)
            let container = MockCloudContainer(
                accountStatus: accountStatus,
                containerIdentifier: containerIdentifier,
                privateCloudDatabase: privateDatabase,
                sharedCloudDatabase: sharedDatabase
            )
            privateDatabase.set(container: container)
            sharedDatabase.set(container: container)
            let notificationCenter = NotificationCenter()
            let testClock = ManualClock()
            let time = ManualTime()
            let uuid = IncrementingUUID()
            self.userDatabase = userDatabase
            self.container = container
            self.inMemoryDataManager = dataManager
            self.notificationCenter = notificationCenter
            self.testClock = testClock
            self.time = time
            self.uuid = uuid
            self.syncEngine = try await SyncEngine(
                container: container,
                userDatabase: userDatabase,
                delegate: delegate,
                tables: Reminder.self,
                RemindersList.self,
                RemindersListAsset.self,
                Tag.self,
                ReminderTag.self,
                Parent.self,
                ChildWithOnDeleteSetNull.self,
                ChildWithOnDeleteSetDefault.self,
                ModelA.self,
                ModelB.self,
                ModelC.self,
                ScopedModel.self,
                privateTables: RemindersListPrivate.self,
                startImmediately: startImmediately,
                context: context,
                notificationCenter: notificationCenter,
                dataManager: dataManager,
                now: { time() },
                uuid: { uuid() },
                clock: testClock
            )
            guard startImmediately, accountStatus == .available
            else { return }
            await syncEngine.handleEvent(
                .accountChange(changeType: .signIn(currentUser: currentUserRecordID)),
                syncEngine: syncEngine.private
            )
            await syncEngine.handleEvent(
                .accountChange(changeType: .signIn(currentUser: currentUserRecordID)),
                syncEngine: syncEngine.shared
            )
            try await syncEngine.processPendingDatabaseChanges(scope: .private)
        }

        func signOut() async {
            container._accountStatus.withLock { $0 = .noAccount }
            await syncEngine.handleEvent(
                .accountChange(changeType: .signOut(previousUser: previousUserRecordID)),
                syncEngine: syncEngine.private
            )
            await syncEngine.handleEvent(
                .accountChange(changeType: .signOut(previousUser: previousUserRecordID)),
                syncEngine: syncEngine.shared
            )
        }

        func softSignOut() async {
            container._accountStatus.withLock { $0 = .temporarilyUnavailable }
        }

        func signIn() async {
            container._accountStatus.withLock { $0 = .available }
            syncEngine.private.state.removePendingChanges()
            syncEngine.shared.state.removePendingChanges()
            await syncEngine.handleEvent(
                .accountChange(changeType: .signIn(currentUser: currentUserRecordID)),
                syncEngine: syncEngine.private
            )
            await syncEngine.handleEvent(
                .accountChange(changeType: .signIn(currentUser: currentUserRecordID)),
                syncEngine: syncEngine.shared
            )
        }

        func withTime<R>(
            advancedBy seconds: Int64,
            _ operation: () throws -> R
        ) rethrows -> R {
            time.advance(by: seconds)
            defer { time.advance(by: -seconds) }
            return try operation()
        }

        func withTime<R>(
            advancedBy seconds: Int64,
            _ operation: () async throws -> R
        ) async rethrows -> R {
            time.advance(by: seconds)
            defer { time.advance(by: -seconds) }
            return try await operation()
        }

        deinit {
            defer { inMemoryDataManager.unregister() }
            guard syncEngine.isRunning
            else { return }

            syncEngine.shared.assertFetchChangesScopes([])
            syncEngine.shared.state.assertPendingDatabaseChanges([])
            syncEngine.shared.state.assertPendingRecordZoneChanges([])
            syncEngine.shared.assertAcceptedShareMetadata([])
            syncEngine.private.assertFetchChangesScopes([])
            syncEngine.private.state.assertPendingDatabaseChanges([])
            syncEngine.private.state.assertPendingRecordZoneChanges([])
            syncEngine.private.assertAcceptedShareMetadata([])

            try! syncEngine.metadatabase.read { db in
                try #expect(UnsyncedRecordID.count().fetchOne(db) == 0)
            }
        }
    }

    extension SyncEngine {
        static nonisolated let defaultTestZone = CKRecordZone(zoneName: "zone")

        convenience init<
            each T1: PrimaryKeyedTable & SendableMetatype,
            each T2: PrimaryKeyedTable & SendableMetatype
        >(
            container: MockCloudContainer,
            userDatabase: UserDatabase,
            delegate: (any SyncEngineDelegate)? = nil,
            tables: repeat (each T1).Type,
            privateTables: repeat (each T2).Type,
            startImmediately: Bool = true,
            context: Context = .test,
            notificationCenter: NotificationCenter = NotificationCenter(),
            dataManager: InMemoryDataManager = InMemoryDataManager(),
            now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 0) },
            uuid: @escaping @Sendable () -> RFC_4122.UUID = IncrementingUUID().callAsFunction,
            clock: ManualClock = ManualClock()
        ) async throws
        where
            repeat (each T1).PrimaryKey.QueryOutput: IdentifierStringConvertible,
            repeat (each T1).TableColumns.PrimaryColumn: WritableTableColumnExpression,
            repeat (each T2).PrimaryKey.QueryOutput: IdentifierStringConvertible,
            repeat (each T2).TableColumns.PrimaryColumn: WritableTableColumnExpression
        {
            var allTables: [any SynchronizableTable] = []
            var allPrivateTables: [any SynchronizableTable] = []
            for table in repeat each tables {
                allTables.append(SynchronizedTable(for: table))
            }
            for privateTable in repeat each privateTables {
                allPrivateTables.append(SynchronizedTable(for: privateTable))
            }
            try await self.init(
                container: container,
                userDatabase: userDatabase,
                delegate: delegate,
                tables: allTables,
                privateTables: allPrivateTables,
                startImmediately: startImmediately,
                context: context,
                notificationCenter: notificationCenter,
                dataManager: dataManager,
                now: now,
                uuid: uuid,
                clock: clock
            )
        }

        convenience init(
            container: MockCloudContainer,
            userDatabase: UserDatabase,
            delegate: (any SyncEngineDelegate)? = nil,
            tables: [any SynchronizableTable],
            privateTables: [any SynchronizableTable] = [],
            startImmediately: Bool = true,
            context: Context = .test,
            notificationCenter: NotificationCenter = NotificationCenter(),
            dataManager: InMemoryDataManager = InMemoryDataManager(),
            now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 0) },
            uuid: @escaping @Sendable () -> RFC_4122.UUID = IncrementingUUID().callAsFunction,
            clock: ManualClock = ManualClock()
        ) async throws {
            try self.init(
                container: container,
                defaultZone: Self.defaultTestZone,
                defaultSyncEngines: { _, syncEngine in
                    (
                        private: MockSyncEngine(
                            database: container.privateCloudDatabase,
                            parentSyncEngine: syncEngine,
                            state: MockSyncEngineState()
                        ),
                        shared: MockSyncEngine(
                            database: container.sharedCloudDatabase,
                            parentSyncEngine: syncEngine,
                            state: MockSyncEngineState()
                        )
                    )
                },
                userDatabase: userDatabase,
                logger: Logger(.disabled),
                delegate: delegate,
                tables: tables,
                privateTables: privateTables,
                context: context,
                notificationCenter: notificationCenter,
                dataManager: dataManager,
                now: now,
                uuid: uuid,
                clock: clock
            )
            try setUpSyncEngine()
            if startImmediately {
                try await start()
            }
        }
    }

    private let previousUserRecordID = CKRecord.ID(recordName: "previousUser")
    private let currentUserRecordID = CKRecord.ID(recordName: "currentUser")

    extension Int: IdentifierStringConvertible {}
#endif
