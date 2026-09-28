public import Tagged

extension Tagged: IdentifierStringConvertible
where Tag: ~Copyable & ~Escapable, Underlying: IdentifierStringConvertible {
  public init?(rawIdentifier: String) {
    guard let underlying = Underlying(rawIdentifier: rawIdentifier) else { return nil }
    self.init(_unchecked: underlying)
  }

  public var rawIdentifier: String {
    underlying.rawIdentifier
  }
}
