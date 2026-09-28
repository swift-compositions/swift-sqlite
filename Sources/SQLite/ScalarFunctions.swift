public import Byte
public import SQL

extension QueryExpression where QueryValue == Bool {
  public func likelihood(
    _ probability: some QueryExpression<some FloatingPoint>
  ) -> some QueryExpression<QueryValue> {
    QueryFunction<QueryValue>("likelihood", self, probability)
  }

  public func likely() -> some QueryExpression<QueryValue> {
    QueryFunction<QueryValue>("likely", self)
  }

  public func unlikely() -> some QueryExpression<QueryValue> {
    QueryFunction<QueryValue>("unlikely", self)
  }
}

extension QueryExpression where QueryValue: BinaryInteger {
  public func randomblob() -> some QueryExpression<[Byte]> {
    QueryFunction<[Byte]>("randomblob", self)
  }

  public func zeroblob() -> some QueryExpression<[Byte]> {
    QueryFunction<[Byte]>("zeroblob", self)
  }
}

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
  public func unicode() -> some QueryExpression<Int?> {
    QueryFunction<Int?>("unicode", self)
  }
}

extension QueryExpression
where QueryValue: _OptionalPromotable, QueryValue._Optionalized.Wrapped: Numeric {
  public func sign() -> some QueryExpression<QueryValue> {
    QueryFunction<QueryValue>("sign", self)
  }
}

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
  public func unhex(
    _ characters: (some QueryExpression<String>)? = String?.none
  ) -> some QueryExpression<[Byte]?> {
    if let characters {
      return QueryFunction<[Byte]?>("unhex", self, characters)
    } else {
      return QueryFunction<[Byte]?>("unhex", self)
    }
  }
}
