public import Comparison
public import SQL

public protocol DatabaseCollation: Collation {
  func compare(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Comparison
}
