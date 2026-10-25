public import ISO_9075_Foundation
public import RFC_4122
public import SQL

extension RFC_4122.UUID {
    public struct UppercasedRepresentation: QueryRepresentable, Sendable {
        public var queryOutput: RFC_4122.UUID

        public init(queryOutput: RFC_4122.UUID) {
            self.queryOutput = queryOutput
        }
    }
}

extension RFC_4122.UUID.UppercasedRepresentation: QueryBindable {
    public var queryBinding: ISO_9075.Value { .text(String(queryOutput).uppercased()) }
}

extension RFC_4122.UUID.UppercasedRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        let string = try String(decoder: &decoder)
        do {
            self.init(queryOutput: try RFC_4122.UUID(string))
        } catch {
            throw .dataCorrupted("\(string) as a UUID")
        }
    }
}

extension RFC_4122.UUID.UppercasedRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity { String.typeAffinity }
}
