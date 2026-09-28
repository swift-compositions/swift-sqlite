public import Byte
public import ISO_9075_Foundation
public import RFC_4122
public import SQL

extension RFC_4122.UUID {
    public struct BytesRepresentation: QueryRepresentable, Sendable {
        public var queryOutput: RFC_4122.UUID

        public init(queryOutput: RFC_4122.UUID) {
            self.queryOutput = queryOutput
        }

        public static func _queryFragment(jsonEncoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
            """
            CASE WHEN \(queryFragment) IS NULL THEN NULL ELSE lower(printf('%s-%s-%s-%s-%s', \
            substr(hex(\(queryFragment)), 1, 8), \
            substr(hex(\(queryFragment)), 9, 4), \
            substr(hex(\(queryFragment)), 13, 4), \
            substr(hex(\(queryFragment)), 17, 4), \
            substr(hex(\(queryFragment)), 21, 12))) END
            """
        }
    }
}

extension RFC_4122.UUID.BytesRepresentation: QueryBindable {
    public var queryBinding: ISO_9075.Value { .blob(queryOutput.byteArray.map(Byte.init)) }
}

extension RFC_4122.UUID.BytesRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        let bytes = try [Byte](decoder: &decoder)
        do {
            self.init(queryOutput: try RFC_4122.UUID(bytes.map(\.underlying)))
        } catch {
            throw .dataCorrupted("\(bytes.count) bytes as a UUID")
        }
    }
}

extension RFC_4122.UUID.BytesRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity { [Byte].typeAffinity }
}
