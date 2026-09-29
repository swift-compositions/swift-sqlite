#if CloudKit
    import GRDB
    import CloudKit
    import Foundation
    import Synchronization

    final class ManualTime: Sendable {
        private let seconds: Mutex<Int64>

        init(secondsSinceUnixEpoch: Int64 = 0) {
            seconds = Mutex(secondsSinceUnixEpoch)
        }

        var secondsSinceUnixEpoch: Int64 {
            seconds.withLock { $0 }
        }

        var nanoseconds: Int64 {
            secondsSinceUnixEpoch * 1_000_000_000
        }

        func callAsFunction() -> Date {
            Date(timeIntervalSince1970: TimeInterval(secondsSinceUnixEpoch))
        }

        func advance(by seconds: Int64) {
            self.seconds.withLock { $0 += seconds }
        }
    }
#endif
