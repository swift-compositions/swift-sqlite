public import ISO_9075_Foundation
import Foundation
public import SQL

#if !SuppressPlatformSQLiteAvailability
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
#endif
public struct _CodableJSONBRepresentation<QueryOutput: Codable>: Codable, QueryRepresentable {
  public var queryOutput: QueryOutput

  public init(queryOutput: QueryOutput) {
    self.queryOutput = queryOutput
  }

  public static func queryFragment(decoding queryFragment: ISO_9075.Fragment) -> ISO_9075.Fragment {
    "json(\(queryFragment))"
  }
}

#if !SuppressPlatformSQLiteAvailability
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
#endif
extension _CodableJSONBRepresentation: Equatable where QueryOutput: Equatable {}

#if !SuppressPlatformSQLiteAvailability
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
#endif
extension _CodableJSONBRepresentation: Hashable where QueryOutput: Hashable {}

#if !SuppressPlatformSQLiteAvailability
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
#endif
extension _CodableJSONBRepresentation: Sendable where QueryOutput: Sendable {}

extension Decodable where Self: Encodable {
  #if !SuppressPlatformSQLiteAvailability
    @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
  #endif
  public typealias JSONBRepresentation = _CodableJSONBRepresentation<Self>
}

extension Optional where Wrapped: Codable {
  @_documentation(visibility: private)
  #if !SuppressPlatformSQLiteAvailability
    @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
  #endif
  public typealias JSONBRepresentation = _CodableJSONBRepresentation<Wrapped>?
}

#if !SuppressPlatformSQLiteAvailability
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
#endif
extension _CodableJSONBRepresentation: QueryBindable {
  public var queryBinding: ISO_9075.Value {
    do {
      return try .text(String(decoding: jsonEncoder.encode(queryOutput), as: UTF8.self))
    } catch {
      return .invalid(error)
    }
  }

  public var queryFragment: ISO_9075.Fragment {
    "jsonb(\(queryBinding))"
  }
}

#if !SuppressPlatformSQLiteAvailability
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
#endif
extension _CodableJSONBRepresentation: QueryDecodable {
  public init(decoder: inout some QueryDecoder) throws {
    self.init(
      queryOutput: try jsonDecoder.decode(
        QueryOutput.self,
        from: Data(String(decoder: &decoder).utf8)
      )
    )
  }
}

#if !SuppressPlatformSQLiteAvailability
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
#endif
extension _CodableJSONBRepresentation: SQLiteType {
  public static var typeAffinity: SQLiteTypeAffinity { .blob }
}
