internal import Foundation
public import ISO_9075_Foundation
public import SQL

public struct JSONRepresentation<QueryOutput: Codable>: Codable, QueryRepresentable {
    public var queryOutput: QueryOutput

    public init(queryOutput: QueryOutput) {
        self.queryOutput = queryOutput
    }

    public static func _queryFragment(jsonEncoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
        "json(\(queryFragment))"
    }
}

extension JSONRepresentation: Equatable where QueryOutput: Equatable {}
extension JSONRepresentation: Hashable where QueryOutput: Hashable {}
extension JSONRepresentation: Sendable where QueryOutput: Sendable {}

extension JSONRepresentation: QueryBindable {
    public var queryBinding: ISO_9075.Value {
        do {
            return .text(String(decoding: try JSONRepresentation.encoder.encode(queryOutput), as: UTF8.self))
        } catch {
            return .invalid(ISO_9075.Value.Failure(error))
        }
    }
}

extension JSONRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        let text = try String(decoder: &decoder)
        do {
            self.init(queryOutput: try JSONRepresentation.decoder.decode(QueryOutput.self, from: Data(text.utf8)))
        } catch {
            throw .dataCorrupted("\(text) as JSON \(QueryOutput.self)")
        }
    }
}

extension JSONRepresentation {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder { JSONDecoder() }
}
