#if GRDB
    public import CustomDump
    public import Time

    extension Time.Instant: @retroactive CustomDumpStringConvertible {
        public var customDumpDescription: String {
            nanosecondFraction == 0
                ? "Time.Instant(secondsSinceUnixEpoch: \(secondsSinceUnixEpoch))"
                : "Time.Instant(secondsSinceUnixEpoch: \(secondsSinceUnixEpoch), nanosecondFraction: \(nanosecondFraction))"
        }
    }

#endif
