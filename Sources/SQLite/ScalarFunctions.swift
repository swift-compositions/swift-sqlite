public import SQL

extension QueryExpression where QueryValue == Bool {
  public func likelihood(
    _ probability: some QueryExpression<some FloatingPoint>
  ) -> some QueryExpression<QueryValue> {
    QueryFunction("likelihood", self, probability)
  }

  public func likely() -> some QueryExpression<QueryValue> {
    QueryFunction("likely", self)
  }

  public func unlikely() -> some QueryExpression<QueryValue> {
    QueryFunction("unlikely", self)
  }
}

extension QueryExpression where QueryValue: BinaryInteger {
  public func randomblob() -> some QueryExpression<[UInt8]> {
    QueryFunction("randomblob", self)
  }

  public func zeroblob() -> some QueryExpression<[UInt8]> {
    QueryFunction("zeroblob", self)
  }
}

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
  public func unicode() -> some QueryExpression<Int?> {
    QueryFunction("unicode", self)
  }
}

extension QueryExpression
where QueryValue: _OptionalPromotable, QueryValue._Optionalized.Wrapped: Numeric {
  public func sign() -> some QueryExpression<QueryValue> {
    QueryFunction("sign", self)
  }
}

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
  public func unhex(
    _ characters: (some QueryExpression<String>)? = String?.none
  ) -> some QueryExpression<[UInt8]?> {
    if let characters {
      return QueryFunction("unhex", self, characters)
    } else {
      return QueryFunction("unhex", self)
    }
  }
}
