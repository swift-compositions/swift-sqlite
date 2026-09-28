#if CloudKit
    import CloudKit
    import CustomDump
    import Foundation
    import InlineSnapshotTesting
    import SQLite
    import Synchronization

    private enum Printing {
        @TaskLocal static var timestamps = false
        @TaskLocal static var recordChangeTags = false
    }

    extension Snapshotting where Format == String {
        static var customDump: Self {
            customDump(timestamps: false)
        }

        static func customDump(timestamps: Bool, recordChangeTags: Bool = false) -> Self {
            SimplySnapshotting.lines.pullback { value in
                Printing.$timestamps.withValue(timestamps) {
                    Printing.$recordChangeTags.withValue(recordChangeTags) {
                        var output = ""
                        CustomDump.customDump(value, to: &output)
                        return output
                    }
                }
            }
        }
    }

    extension InMemoryDataManager {
        static let registered = Mutex<[InMemoryDataManager]>([])

        func register() {
            Self.registered.withLock { $0.append(self) }
        }

        func unregister() {
            Self.registered.withLock { $0.removeAll { $0 === self } }
        }

        static func data(at url: URL) -> Data? {
            registered.withLock { $0 }.lazy.compactMap { try? $0.load(url) }.first
        }
    }

    extension CKDatabase.Scope: @retroactive CustomDumpStringConvertible {
        public var customDumpDescription: String {
            switch self {
            case .public: ".public"
            case .private: ".private"
            case .shared: ".shared"
            @unknown default: "@unknown"
            }
        }
    }

    extension CKRecord: @retroactive CustomDumpReflectable {
        public var customDumpMirror: Mirror {
            let timeKey = CKRecord.userModificationTimeKey
            let keys = encryptedValues.allKeys()
                .filter { key in Printing.timestamps || !key.hasPrefix(timeKey) }
                .sorted { lhs, rhs in
                    guard lhs != timeKey else { return false }
                    guard rhs != timeKey else { return true }
                    let lhsHasPrefix = lhs.hasPrefix(timeKey)
                    let baseLHS = lhsHasPrefix ? String(lhs.dropFirst(timeKey.count + 1)) : lhs
                    let rhsHasPrefix = rhs.hasPrefix(timeKey)
                    let baseRHS = rhsHasPrefix ? String(rhs.dropFirst(timeKey.count + 1)) : rhs
                    return (baseLHS, lhsHasPrefix ? 1 : 0) < (baseRHS, rhsHasPrefix ? 1 : 0)
                }
            let nonEncryptedKeys = Set(allKeys())
                .subtracting(encryptedValues.allKeys())
                .subtracting(["_recordChangeTag"])
            let baseChildren: [(String, Any)] =
                [
                    ("recordID", recordID as Any),
                    ("recordType", recordType as Any),
                    ("parent", parent as Any),
                    ("share", share as Any),
                ]
                + (Printing.recordChangeTags ? [("recordChangeTag", _recordChangeTag as Any)] : [])
            return Mirror(
                self,
                children: baseChildren
                    + keys.map { key -> (String, Any) in
                        key.hasPrefix(timeKey)
                            ? (
                                String(key.dropFirst(timeKey.count + 1)) + "🗓️",
                                (encryptedValues[key] as? Int64) as Any
                            )
                            : (key, encryptedValues[key] as Any)
                    }
                    + nonEncryptedKeys.map { key -> (String, Any) in (key, self[key] as Any) },
                displayStyle: .struct
            )
        }
    }

    extension CKAsset: @retroactive CustomDumpReflectable {
        public var customDumpMirror: Mirror {
            Mirror(
                self,
                children: [
                    ("fileURL", fileURL as Any),
                    (
                        "dataString",
                        String(
                            decoding: fileURL.flatMap(InMemoryDataManager.data(at:)) ?? Data(),
                            as: UTF8.self
                        )
                    ),
                ],
                displayStyle: .struct
            )
        }
    }

    extension CKRecord.Reference: @retroactive CustomDumpReflectable {
        public var customDumpMirror: Mirror {
            Mirror(self, children: [("recordID", recordID as Any)], displayStyle: .struct)
        }
    }

    extension CKSyncEngine.RecordZoneChangeBatch: @retroactive CustomDumpReflectable {
        public var customDumpMirror: Mirror {
            Mirror(
                self,
                children: [
                    ("atomicByZone", atomicByZone as Any),
                    (
                        "recordIDsToDelete",
                        recordIDsToDelete.sorted { $0.recordName < $1.recordName } as Any
                    ),
                    (
                        "recordsToSave",
                        recordsToSave.sorted { $0.recordID.recordName < $1.recordID.recordName } as Any
                    ),
                ],
                displayStyle: .struct
            )
        }
    }

    extension CKRecord.ID: @retroactive CustomDumpStringConvertible {
        public var customDumpDescription: String {
            "CKRecord.ID(\(recordName)/\(zoneID.zoneName)/\(zoneID.ownerName))"
        }
    }

    extension CKRecordZone.ID: @retroactive CustomDumpStringConvertible {
        public var customDumpDescription: String {
            "CKRecordZone.ID(\(zoneName)/\(ownerName))"
        }
    }

    extension MockSyncEngineState: CustomDumpReflectable {
        package var customDumpMirror: Mirror {
            Mirror(
                self,
                children: [
                    (
                        "pendingRecordZoneChanges",
                        pendingRecordZoneChanges.sorted(by: pendingRecordZoneChangeOrder) as Any
                    ),
                    (
                        "pendingDatabaseChanges",
                        pendingDatabaseChanges.sorted(by: pendingDatabaseChangeOrder) as Any
                    ),
                ],
                displayStyle: .struct
            )
        }
    }

    private func pendingRecordZoneChangeOrder(
        _ lhs: CKSyncEngine.PendingRecordZoneChange,
        _ rhs: CKSyncEngine.PendingRecordZoneChange
    ) -> Bool {
        switch (lhs, rhs) {
        case (.saveRecord(let lhs), .saveRecord(let rhs)), (.deleteRecord(let lhs), .deleteRecord(let rhs)):
            lhs.recordName < rhs.recordName
        case (.deleteRecord, .saveRecord):
            true
        default:
            false
        }
    }

    private func pendingDatabaseChangeOrder(
        _ lhs: CKSyncEngine.PendingDatabaseChange,
        _ rhs: CKSyncEngine.PendingDatabaseChange
    ) -> Bool {
        switch (lhs, rhs) {
        case (.saveZone(let lhs), .saveZone(let rhs)):
            lhs.zoneID.zoneName < rhs.zoneID.zoneName
        case (.deleteZone(let lhs), .deleteZone(let rhs)):
            lhs.zoneName < rhs.zoneName
        case (.deleteZone, .saveZone):
            true
        default:
            false
        }
    }

    extension MockCloudContainer: CustomDumpReflectable {
        package var customDumpMirror: Mirror {
            Mirror(
                self,
                children: [
                    ("privateCloudDatabase", privateCloudDatabase),
                    ("sharedCloudDatabase", sharedCloudDatabase),
                ],
                displayStyle: .struct
            )
        }
    }

    extension MockCloudDatabase: CustomDumpReflectable {
        package var customDumpMirror: Mirror {
            Mirror(
                self,
                children: [
                    "databaseScope": databaseScope,
                    "storage": state.withLock { state in
                        state.storage
                            .flatMap { _, zone in zone.records.values }
                            .sorted {
                                ($0.recordType, $0.recordID.recordName)
                                    < ($1.recordType, $1.recordID.recordName)
                            }
                    },
                ],
                displayStyle: .struct
            )
        }
    }

    extension RecordType: CustomDumpReflectable {
        package var customDumpMirror: Mirror {
            Mirror(
                self,
                children: [
                    ("tableName", tableName as Any),
                    ("schema", schema),
                    ("tableInfo", tableInfo.sorted { $0.name < $1.name }),
                ],
                displayStyle: .struct
            )
        }
    }
#endif
