public import ISO_9075_Foundation
public import SQL
public import Time

extension Time.Instant {
    public struct JulianDayRepresentation: QueryRepresentable, Sendable {
        public var queryOutput: Time.Instant

        public init(queryOutput: Time.Instant) {
            self.queryOutput = queryOutput
        }

        public static func _queryFragment(jsonEncoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
            subsecDateTime([queryFragment, "'julianday'"])
        }

        public static func _queryFragment(jsonDecoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
            "julianday(\(queryFragment))"
        }
    }
}

extension Time.Instant.JulianDayRepresentation: QueryBindable {
    public var queryBinding: ISO_9075.Value {
        .double(
            2_440_587.5
                + (Double(queryOutput.secondsSinceUnixEpoch) + Double(queryOutput.nanosecondFraction) / 1_000_000_000)
                / 86_400
        )
    }
}

extension Time.Instant.JulianDayRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        self.init(queryOutput: Time.Instant(secondsSinceUnixEpoch: (try Double(decoder: &decoder) - 2_440_587.5) * 86_400))
    }
}

extension Time.Instant.JulianDayRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity { Double.typeAffinity }
}

extension Time.Instant {
    init(secondsSinceUnixEpoch seconds: Double) {
        let whole = seconds.rounded(.down)
        self.init(
            _unchecked: (),
            secondsSinceUnixEpoch: Int64(whole),
            nanosecondFraction: Int32(((seconds - whole) * 1_000_000_000).rounded(.down))
        )
    }
}
