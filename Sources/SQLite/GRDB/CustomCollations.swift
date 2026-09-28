#if GRDB
import GRDBSQLite
public import Comparison
public import GRDB
public import SQL


extension GRDB.Database {
  public func add(collation: some DatabaseCollation) {
    sqlite3_create_collation_v2(
      sqliteConnection,
      collation.name,
      SQLITE_UTF8,
      Unmanaged.passRetained(DatabaseCollationDefinition(collation)).toOpaque(),
      { context, lhsCount, lhs, rhsCount, rhs in
        switch Unmanaged<DatabaseCollationDefinition>
          .fromOpaque(context!)
          .takeUnretainedValue()
          .collation
          .compare(
            UnsafeRawBufferPointer(start: lhs, count: Int(lhsCount)),
            UnsafeRawBufferPointer(start: rhs, count: Int(rhsCount))
          )
        {
        case .less: return -1
        case .equal: return 0
        case .greater: return 1
        }
      },
      { context in
        guard let context else { return }
        Unmanaged<DatabaseCollationDefinition>.fromOpaque(context).release()
      }
    )
  }
  public func remove(collation: some DatabaseCollation) {
    sqlite3_create_collation_v2(
      sqliteConnection,
      collation.name,
      SQLITE_UTF8,
      nil,
      nil,
      nil
    )
  }
}

extension Collation where Self == CanonicalCollation {
  public static var canonical: Self { Self() }
}
public nonisolated struct CanonicalCollation: DatabaseCollation, Sendable {
  public var name: String { "canonical" }
  public init() {}
  public func compare(
    _ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer
  ) -> Comparison {
    do {
      let lhsSpan = try UTF8Span(validating: lhs.assumingMemoryBound(to: UInt8.self).span)
      let rhsSpan = try UTF8Span(validating: rhs.assumingMemoryBound(to: UInt8.self).span)
      return lhsSpan.isCanonicallyLessThan(rhsSpan) ? .less : rhsSpan.isCanonicallyLessThan(lhsSpan) ? .greater : .equal
    } catch {
      return lhs.elementsEqual(rhs) ? .equal : lhs.lexicographicallyPrecedes(rhs) ? .less : .greater
    }
  }
}

private final class DatabaseCollationDefinition {
  let collation: any DatabaseCollation
  init(_ collation: some DatabaseCollation) {
    self.collation = collation
  }
}

#endif
