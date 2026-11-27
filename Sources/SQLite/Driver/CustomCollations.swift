public import SQLite_SQL
internal import SQLite_Shims
public import Order
public import SQL

extension SQLite.Connection {
    /// Adds `collation` to this connection. Call it from ``SQLite/Configuration/prepareDatabase(_:)`` to have it on
    /// every connection.
    public func add(collation: some SQLite_SQL::DatabaseCollation) {
        core.add(collation: collation)
    }

    public func remove(collation: some SQLite_SQL::DatabaseCollation) {
        core.remove(collation: collation)
    }
}

extension SQLite.Connection.Core {
    func add(collation: some SQLite_SQL::DatabaseCollation) {
        unsafe sqlite3_create_collation_v2(
            pointer,
            collation.name,
            SQLITE_UTF8,
            Unmanaged.passRetained(DatabaseCollationDefinition(collation)).toOpaque(),
            { context, lhsCount, lhs, rhsCount, rhs in
                guard let context = unsafe context else { return 0 }
                switch unsafe Unmanaged<DatabaseCollationDefinition>
                    .fromOpaque(context)
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
                guard let context = unsafe context else { return }
                unsafe Unmanaged<DatabaseCollationDefinition>.fromOpaque(context).release()
            }
        )
    }
    func remove(collation: some SQLite_SQL::DatabaseCollation) {
        unsafe sqlite3_create_collation_v2(
            pointer,
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
public nonisolated struct CanonicalCollation: SQLite_SQL::DatabaseCollation, Sendable {
    public var name: String { "canonical" }
    public init() {}
    public func compare(
        _ lhs: UnsafeRawBufferPointer,
        _ rhs: UnsafeRawBufferPointer
    ) -> Order.Comparison {
        do {
            let lhsSpan = unsafe try UTF8Span(validating: lhs.assumingMemoryBound(to: UInt8.self).span)
            let rhsSpan = unsafe try UTF8Span(validating: rhs.assumingMemoryBound(to: UInt8.self).span)
            return lhsSpan.isCanonicallyLessThan(rhsSpan) ? .less : rhsSpan.isCanonicallyLessThan(lhsSpan) ? .greater : .equal
        } catch {
            return unsafe lhs.elementsEqual(rhs) ? .equal : lhs.lexicographicallyPrecedes(rhs) ? .less : .greater
        }
    }
}

private final class DatabaseCollationDefinition {
    let collation: any SQLite_SQL::DatabaseCollation
    init(_ collation: some SQLite_SQL::DatabaseCollation) {
        self.collation = collation
    }
}

