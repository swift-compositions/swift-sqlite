public import ISO_9075_Foundation
public import SQL
public import Time

extension Instant {
    public struct UnixTimeRepresentation: QueryRepresentable, Sendable {
        public var queryOutput: Instant

        public init(queryOutput: Instant) {
            self.queryOutput = queryOutput
        }

        public static func _queryFragment(jsonEncoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
            "datetime(\(queryFragment), 'unixepoch')"
        }

        public static func _queryFragment(jsonDecoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
            "unixepoch(\(queryFragment))"
        }
    }
}

extension Instant.UnixTimeRepresentation: QueryBindable {
    public var queryBinding: ISO_9075.Value { .int(queryOutput.secondsSinceUnixEpoch) }
}

extension Instant.UnixTimeRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        self.init(queryOutput: Instant(secondsSinceUnixEpoch: try Int64(decoder: &decoder)))
    }
}

extension Instant.UnixTimeRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity { Int.typeAffinity }
}
