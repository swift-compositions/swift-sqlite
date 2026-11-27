#if CloudKit && canImport(CloudKit)
    public import CloudKit
    import Foundation
    import SQLite
    import SQLite_CloudKit
    import Synchronization
    import Test

    private enum Printing {
        @TaskLocal static var timestamps = false
        @TaskLocal static var recordChangeTags = false
    }

    /// A value that draws itself in a state snapshot through the children of a mirror.
    package protocol StateMirroring {
        var stateMirror: Mirror { get }
    }

    /// A value that draws itself in a state snapshot as one line.
    package protocol StateDescribing {
        var stateDescription: String { get }
    }

    extension Test::Test.Snapshot.Strategy where Format == String {
        /// The value drawn as the CloudKit tests' state: one line per property, nested by two spaces.
        static var state: Self {
            state(timestamps: false)
        }

        static func state(timestamps: Bool, recordChangeTags: Bool = false) -> Self {
            Test::Test.Snapshot.Strategy<String, String>.lines.pullback { value in
                Printing.$timestamps.withValue(timestamps) {
                    Printing.$recordChangeTags.withValue(recordChangeTags) {
                        State.render(value, indent: "")
                    }
                }
            }
        }
    }

    enum State {
        /// Draws a value for a rows snapshot when it draws itself in a state snapshot.
        static func draw(_ value: Any) -> String? {
            let mirror = Mirror(reflecting: value)
            if mirror.displayStyle == .optional {
                return mirror.children.first.flatMap { draw($0.value) }
            }
            guard value is any StateMirroring || value is any StateDescribing || mirror.displayStyle == .enum else {
                return nil
            }
            return render(value, indent: "")
        }

        static func render(_ value: Any, indent: String) -> String {
            if let value = value as? any StateDescribing { return value.stateDescription }
            if let string = value as? String { return String(reflecting: string) }
            if let data = value as? Data { return "Data(\(data.count) bytes)" }
            let mirror = (value as? any StateMirroring)?.stateMirror ?? Mirror(reflecting: value)
            let inner = indent + "  "
            switch mirror.displayStyle {
            case .optional:
                return mirror.children.first.map { render($0.value, indent: indent) } ?? "nil"
            case .collection, .set:
                let elements = mirror.children.enumerated().map { offset, child in
                    "\(inner)[\(offset)]: \(render(child.value, indent: inner))"
                }
                return elements.isEmpty ? "[]" : "[\n" + elements.joined(separator: ",\n") + "\n\(indent)]"
            case .dictionary:
                let entries = mirror.children.map { child -> (String, String) in
                    let pair = Array(Mirror(reflecting: child.value).children)
                    return (render(pair[0].value, indent: inner), render(pair[1].value, indent: inner))
                }
                .sorted { $0.0 < $1.0 }
                .map { "\(inner)\($0): \($1)" }
                return entries.isEmpty ? "[:]" : "[\n" + entries.joined(separator: ",\n") + "\n\(indent)]"
            case .enum:
                guard let payload = mirror.children.first else { return ".\(value)" }
                return ".\(payload.label ?? "")(\(render(payload.value, indent: indent)))"
            case .struct, .class, .tuple:
                if !(value is any StateMirroring), let value = value as? any CustomStringConvertible {
                    return value.description
                }
                let name = mirror.displayStyle == .tuple ? "" : "\(mirror.subjectType)"
                let fields = mirror.children.map { child in
                    "\(inner)\(child.label ?? "_"): \(render(child.value, indent: inner))"
                }
                return fields.isEmpty ? "\(name)()" : "\(name)(\n" + fields.joined(separator: ",\n") + "\n\(indent))"
            case nil:
                return String(describing: value)
            @unknown default:
                return String(describing: value)
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

    extension CKDatabase.Scope: StateDescribing {
        public var stateDescription: String {
            switch self {
            case .public: ".public"
            case .private: ".private"
            case .shared: ".shared"
            @unknown default: "@unknown"
            }
        }
    }

    extension CKRecord: StateMirroring {
        public var stateMirror: Mirror {
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

    extension CKAsset: StateMirroring {
        public var stateMirror: Mirror {
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

    extension CKRecord.Reference: StateMirroring {
        public var stateMirror: Mirror {
            Mirror(self, children: [("recordID", recordID as Any)], displayStyle: .struct)
        }
    }

    extension CKSyncEngine.RecordZoneChangeBatch: StateMirroring {
        public var stateMirror: Mirror {
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

    extension CKRecord.ID: StateDescribing {
        public var stateDescription: String {
            "CKRecord.ID(\(recordName)/\(zoneID.zoneName)/\(zoneID.ownerName))"
        }
    }

    extension CKRecordZone.ID: StateDescribing {
        public var stateDescription: String {
            "CKRecordZone.ID(\(zoneName)/\(ownerName))"
        }
    }

    extension MockSyncEngineState: StateMirroring {
        package var stateMirror: Mirror {
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

    extension MockCloudContainer: StateMirroring {
        package var stateMirror: Mirror {
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

    extension MockCloudDatabase: StateMirroring {
        package var stateMirror: Mirror {
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

    extension RecordType: StateMirroring {
        package var stateMirror: Mirror {
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
