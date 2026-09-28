internal import Foundation
public import ISO_9075_Foundation
public import SQL

public struct JSONBRepresentation<QueryOutput: Codable>: Codable, QueryRepresentable {
    public var queryOutput: QueryOutput

    public init(queryOutput: QueryOutput) {
        self.queryOutput = queryOutput
    }

    public static func queryFragment(decoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
        "json(\(queryFragment))"
    }
}

extension JSONBRepresentation: Equatable where QueryOutput: Equatable {}
extension JSONBRepresentation: Hashable where QueryOutput: Hashable {}
extension JSONBRepresentation: Sendable where QueryOutput: Sendable {}

extension JSONBRepresentation: QueryBindable {
    public var queryBinding: ISO_9075.Value {
        JSONRepresentation(queryOutput: queryOutput).queryBinding
    }

    public var queryFragment: ISO_9075.Fragment {
        "jsonb(\(queryBinding))"
    }
}

extension JSONBRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        self.init(queryOutput: try JSONRepresentation<QueryOutput>(decoder: &decoder).queryOutput)
    }
}

extension JSONBRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity { .blob }
}
