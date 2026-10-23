#if CloudKit
    #if canImport(CloudKit)
        public import CloudKit
        import GRDB
        import OSLog
        public import SQL
        import RFC_4122
        public import SQLite
        import Synchronization

        extension SyncEngine {
            /// One mock CloudKit container that several sync engines share, as the devices signed in to one iCloud
            /// account share a container. Not upstream: sqlite-data's tests give each engine a container of its own, so
            /// they cannot show two devices converging. For tests only.
            @_spi(Testing)
            public final class Mock: Sendable {
                package let container: MockCloudContainer
                package let dataManager = InMemoryDataManager()

                /// - Parameter identifier: The container's identifier; a new one of its own when nil.
                public init(identifier: String? = nil) {
                    let identifier = identifier ?? "iCloud.org.swift-institute.SQLite.Mock.\(systemRandomUUID())"
                    let privateDatabase = MockCloudDatabase(databaseScope: .private, dataManager: dataManager)
                    let sharedDatabase = MockCloudDatabase(databaseScope: .shared, dataManager: dataManager)
                    container = MockCloudContainer(
                        containerIdentifier: identifier,
                        privateCloudDatabase: privateDatabase,
                        sharedCloudDatabase: sharedDatabase
                    )
                    privateDatabase.set(container: container)
                    sharedDatabase.set(container: container)
                }
            }
        }

        extension SyncEngine.Mock {
            /// The account's status as every engine on this cloud sees it.
            public var account: CKAccountStatus {
                get { container._accountStatus.withLock { $0 } }
                set { container._accountStatus.withLock { $0 = newValue } }
            }

            /// The records in a zone of the private database, copies of what the server holds.
            public func records(in zone: CKRecordZone.ID) -> [CKRecord] {
                container.privateCloudDatabase.state.withLock { state in
                    (state.storage[zone]?.records.values).map { $0.compactMap { $0.copy() as? CKRecord } } ?? []
                }
            }

            /// Removes a zone of the private database and every record in it, as deleting an app's data in iCloud
            /// settings or resetting the development environment does. Engines learn of it through
            /// ``SyncEngine/receive(deletion:reason:)``.
            public func delete(zone: CKRecordZone.ID) {
                container.privateCloudDatabase.state.withLock { $0.storage[zone] = nil }
            }
        }

        extension SyncEngine {
            /// A sync engine on a shared ``Mock``. It starts stopped; call ``start()`` and then ``receive(_:)`` with
            /// `.signIn`, as CloudKit does on a first launch.
            @_spi(Testing)
            public convenience init<
                each T1: PrimaryKeyedTable & _SendableMetatype,
                each T2: PrimaryKeyedTable & _SendableMetatype
            >(
                for database: SQLite.Database,
                tables: repeat (each T1).Type,
                privateTables: repeat (each T2).Type,
                mock: Mock,
                defaultZone: CKRecordZone = CKRecordZone(zoneName: "org.swift-institute.SQLite.defaultZone"),
                delegate: (any SyncEngineDelegate)? = nil,
                now: @escaping @Sendable () -> Date = Date.init
            ) throws
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
                let container = mock.container
                try self.init(
                    container: container,
                    defaultZone: defaultZone,
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
                    userDatabase: UserDatabase(database: database.writer),
                    logger: Logger(.disabled),
                    delegate: delegate,
                    tables: allTables,
                    privateTables: allPrivateTables,
                    context: .test,
                    dataManager: mock.dataManager,
                    now: now
                )
                try setUpSyncEngine()
            }

            /// Delivers an account change to the engine, as CloudKit does. A stopped engine receives nothing, as a
            /// stopped CKSyncEngine does.
            @_spi(Testing)
            public func receive(_ change: CKSyncEngine.Event.AccountChange.ChangeType) async {
                let (privateSyncEngine, sharedSyncEngine) = syncEngines.withLock { ($0.private, $0.shared) }
                if let privateSyncEngine { await handleEvent(.accountChange(changeType: change), syncEngine: privateSyncEngine) }
                if let sharedSyncEngine { await handleEvent(.accountChange(changeType: change), syncEngine: sharedSyncEngine) }
            }

            /// Delivers the deletion of a zone of the private database to the engine, as CloudKit does on the next fetch
            /// after ``Mock/delete(zone:)``.
            @_spi(Testing)
            public func receive(deletion zone: CKRecordZone.ID, reason: CKDatabase.DatabaseChange.Deletion.Reason) async {
                await handleEvent(
                    .fetchedDatabaseChanges(modifications: [], deletions: [(zoneID: zone, reason: reason)]),
                    syncEngine: `private`
                )
            }

            /// The engine's default zone.
            @_spi(Testing)
            public var zone: CKRecordZone.ID { defaultZone.zoneID }
        }
    #endif
#endif
