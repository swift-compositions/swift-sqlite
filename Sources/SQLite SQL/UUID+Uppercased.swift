public import ISO_9075_Foundation
public import RFC_4122
public import SQL

extension IETF.RFC.`4122`.UUID {
    public struct UppercasedRepresentation: QueryRepresentable, Sendable {
        public var queryOutput: IETF.RFC.`4122`.UUID

        public init(queryOutput: IETF.RFC.`4122`.UUID) {
            self.queryOutput = queryOutput
        }
    }
}

extension IETF.RFC.`4122`.UUID.UppercasedRepresentation: QueryBindable {
    public var queryBinding: ISO.`9075`.Value { .text(String(queryOutput).uppercased()) }
}

extension IETF.RFC.`4122`.UUID.UppercasedRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        let string = try String(decoder: &decoder)
        do {
            self.init(queryOutput: try IETF.RFC.`4122`.UUID(string))
        } catch {
            throw .dataCorrupted("\(string) as a UUID")
        }
    }
}

extension IETF.RFC.`4122`.UUID.UppercasedRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity { String.typeAffinity }
}
