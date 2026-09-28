#if CloudKit
public import RFC_4122

public protocol IdentifierStringConvertible {
  init?(rawIdentifier: String)
  var rawIdentifier: String { get }
}

extension IdentifierStringConvertible where Self: CustomStringConvertible {
  public var rawIdentifier: String { description }
}

extension IdentifierStringConvertible where Self: LosslessStringConvertible {
  public init?(rawIdentifier: String) {
    self.init(rawIdentifier)
  }
}

extension String: IdentifierStringConvertible {}

extension Substring: IdentifierStringConvertible {}

extension RFC_4122.UUID: IdentifierStringConvertible {
  public init?(rawIdentifier: String) {
    try? self.init(rawIdentifier)
  }
  public var rawIdentifier: String {
    String(self).lowercased()
  }
}

#endif
