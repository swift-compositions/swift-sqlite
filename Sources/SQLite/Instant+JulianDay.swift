public import ISO_9075_Foundation
public import SQL
public import Time

extension Instant {
    public struct JulianDayRepresentation: QueryRepresentable, Sendable {
        public var queryOutput: Instant

        public init(queryOutput: Instant) {
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

extension Instant.JulianDayRepresentation: QueryBindable {
    public var queryBinding: ISO_9075.Value {
        .double(
            2_440_587.5
                + (Double(queryOutput.secondsSinceUnixEpoch) + Double(queryOutput.nanosecondFraction) / 1_000_000_000)
                / 86_400
        )
    }
}

extension Instant.JulianDayRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        self.init(queryOutput: Instant(secondsSinceUnixEpoch: (try Double(decoder: &decoder) - 2_440_587.5) * 86_400))
    }
}

extension Instant.JulianDayRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity { Double.typeAffinity }
}

extension Instant {
    init(secondsSinceUnixEpoch seconds: Double) {
        let whole = seconds.rounded(.down)
        self.init(
            _unchecked: (),
            secondsSinceUnixEpoch: Int64(whole),
            nanosecondFraction: Int32(((seconds - whole) * 1_000_000_000).rounded(.down))
        )
    }
}
