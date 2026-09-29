#if CloudKit
    import GRDB
    import CloudKit
    import RFC_4122
    import Synchronization

    final class IncrementingUUID: Sendable {
        private let count = Mutex<UInt64>(0)

        func callAsFunction() -> RFC_4122.UUID {
            RFC_4122.UUID(
                count.withLock { count in
                    defer { count += 1 }
                    return count
                }
            )
        }
    }

    extension RFC_4122.UUID {
        init(_ value: UInt64) {
            self.init(
                bytes: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    UInt8(truncatingIfNeeded: value >> 56),
                    UInt8(truncatingIfNeeded: value >> 48),
                    UInt8(truncatingIfNeeded: value >> 40),
                    UInt8(truncatingIfNeeded: value >> 32),
                    UInt8(truncatingIfNeeded: value >> 24),
                    UInt8(truncatingIfNeeded: value >> 16),
                    UInt8(truncatingIfNeeded: value >> 8),
                    UInt8(truncatingIfNeeded: value)
                )
            )
        }
    }
#endif
