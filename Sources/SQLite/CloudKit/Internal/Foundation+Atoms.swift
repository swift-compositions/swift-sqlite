#if CloudKit
#if canImport(CloudKit)
  import Byte
  import Foundation
  import Time

  extension Date {
    init(_ instant: Time.Instant) {
      self.init(
        timeIntervalSince1970: Double(instant.secondsSinceUnixEpoch)
          + Double(instant.nanosecondFraction) / 1_000_000_000
      )
    }
  }

  extension Time.Instant {
    init(_ date: Date) {
      let seconds = date.timeIntervalSince1970.rounded(.down)
      self.init(
        _unchecked: (),
        secondsSinceUnixEpoch: Int64(seconds),
        nanosecondFraction: min(
          Int32(((date.timeIntervalSince1970 - seconds) * 1_000_000_000).rounded()),
          999_999_999
        )
      )
    }
  }

  extension [Byte] {
    init(_ data: Data) {
      self = data.map(Byte.init(bitPattern:))
    }
  }

  extension Data {
    init(_ bytes: [Byte]) {
      self.init(bytes.map(\.bitPattern))
    }
  }
#endif

#endif
