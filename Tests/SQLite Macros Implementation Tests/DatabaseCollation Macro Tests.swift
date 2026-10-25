import MacroTesting
import SQLite_Macros_Implementation
import SnapshotTesting
import Testing

@Suite(.macros(["DatabaseCollation": DatabaseCollationMacro.self], record: .missing))
struct `DatabaseCollation macro` {
    @Test func `a String collation marks its raw buffer decoding unsafe`() {
        assertMacro {
            """
            @DatabaseCollation
            private func localized(_ lhs: String, _ rhs: String) -> Order.Comparison {
              Order.Comparison(lhs, rhs)
            }
            """
        } expansion: {
            """
            private func localized(_ lhs: String, _ rhs: String) -> Order.Comparison {
              Order.Comparison(lhs, rhs)
            }

            private nonisolated var $localized: __macro_local_9localizedfMu_ {
              #if DEBUG
              #sourceLocation(file: "Test.swift", line: 1)
              #SQLiteIsolationCheck(collation: localized)
              #sourceLocation()
              #endif
              return __macro_local_9localizedfMu_()
            }

            private nonisolated func __macro_local_9localizedfMu0_(
              _ arg0: String, _ arg1: String
            ) -> Order.Comparison {
              localized(arg0, arg1)
            }

            private nonisolated struct __macro_local_9localizedfMu_: SQLite_SQL::DatabaseCollation {
              public var name: Swift.String {
                "localized"
              }
              public init() {
              }
              public func compare(
                _ lhs: Swift.UnsafeRawBufferPointer, _ rhs: Swift.UnsafeRawBufferPointer
              ) -> Order::Order.Comparison {
                return unsafe __macro_local_9localizedfMu0_(Swift.String(decoding: lhs, as: Swift.UTF8.self), Swift.String(decoding: rhs, as: Swift.UTF8.self))
              }
            }
            """
        }
    }

    @Test func `a raw buffer collation marks its call unsafe`() {
        assertMacro {
            """
            @DatabaseCollation
            func bytes(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Order.Comparison {
              .equal
            }
            """
        } expansion: {
            """
            func bytes(_ lhs: UnsafeRawBufferPointer, _ rhs: UnsafeRawBufferPointer) -> Order.Comparison {
              .equal
            }

            nonisolated var $bytes: __macro_local_5bytesfMu_ {
              #if DEBUG
              #sourceLocation(file: "Test.swift", line: 1)
              #SQLiteIsolationCheck(collation: bytes)
              #sourceLocation()
              #endif
              return __macro_local_5bytesfMu_()
            }

            nonisolated func __macro_local_5bytesfMu0_(
              _ arg0: UnsafeRawBufferPointer, _ arg1: UnsafeRawBufferPointer
            ) -> Order.Comparison {
              unsafe bytes(arg0, arg1)
            }

            nonisolated struct __macro_local_5bytesfMu_: SQLite_SQL::DatabaseCollation {
              public var name: Swift.String {
                "bytes"
              }
              public init() {
              }
              public func compare(
                _ lhs: Swift.UnsafeRawBufferPointer, _ rhs: Swift.UnsafeRawBufferPointer
              ) -> Order::Order.Comparison {
                return unsafe __macro_local_5bytesfMu0_(lhs, rhs)
              }
            }
            """
        }
    }

    @Test func `a UTF8Span collation marks its span construction unsafe`() {
        assertMacro {
            """
            @DatabaseCollation
            func text(_ lhs: UTF8Span, _ rhs: UTF8Span) -> Order.Comparison {
              .equal
            }
            """
        } expansion: {
            """
            func text(_ lhs: UTF8Span, _ rhs: UTF8Span) -> Order.Comparison {
              .equal
            }

            #if DEBUG
            func __macro_local_18textIsolationProbefMu_() {
            }
            #endif

            nonisolated var $text: __macro_local_4textfMu_ {
              #if DEBUG
              #sourceLocation(file: "Test.swift", line: 1)
              #SQLiteIsolationCheck(collation: __macro_local_18textIsolationProbefMu_)
              #sourceLocation()
              #endif
              return __macro_local_4textfMu_()
            }

            nonisolated func __macro_local_4textfMu0_(
              _ arg0: UTF8Span, _ arg1: UTF8Span
            ) -> Order.Comparison {
              text(arg0, arg1)
            }

            nonisolated struct __macro_local_4textfMu_: SQLite_SQL::DatabaseCollation {
              public var name: Swift.String {
                "text"
              }
              public init() {
              }
              public func compare(
                _ lhs: Swift.UnsafeRawBufferPointer, _ rhs: Swift.UnsafeRawBufferPointer
              ) -> Order::Order.Comparison {
                do {
                  let lhsSpan = try unsafe Swift.UTF8Span(validating: lhs.assumingMemoryBound(to: Swift.UInt8.self).span)
                  let rhsSpan = try unsafe Swift.UTF8Span(validating: rhs.assumingMemoryBound(to: Swift.UInt8.self).span)
                  return __macro_local_4textfMu0_(lhsSpan, rhsSpan)
                } catch {
                  return unsafe lhs.elementsEqual(rhs)
                  ? .equal
                  : lhs.lexicographicallyPrecedes(rhs) ? .less : .greater
                }
              }
            }
            """
        }
    }

    @Test func `a byte span collation marks its span projection unsafe`() {
        assertMacro {
            """
            @DatabaseCollation
            func spans(_ lhs: Span<UInt8>, _ rhs: Span<UInt8>) -> Order.Comparison {
              .equal
            }
            """
        } expansion: {
            """
            func spans(_ lhs: Span<UInt8>, _ rhs: Span<UInt8>) -> Order.Comparison {
              .equal
            }

            #if DEBUG
            func __macro_local_19spansIsolationProbefMu_() {
            }
            #endif

            nonisolated var $spans: __macro_local_5spansfMu_ {
              #if DEBUG
              #sourceLocation(file: "Test.swift", line: 1)
              #SQLiteIsolationCheck(collation: __macro_local_19spansIsolationProbefMu_)
              #sourceLocation()
              #endif
              return __macro_local_5spansfMu_()
            }

            nonisolated func __macro_local_5spansfMu0_(
              _ arg0: Span<UInt8>, _ arg1: Span<UInt8>
            ) -> Order.Comparison {
              spans(arg0, arg1)
            }

            nonisolated struct __macro_local_5spansfMu_: SQLite_SQL::DatabaseCollation {
              public var name: Swift.String {
                "spans"
              }
              public init() {
              }
              public func compare(
                _ lhs: Swift.UnsafeRawBufferPointer, _ rhs: Swift.UnsafeRawBufferPointer
              ) -> Order::Order.Comparison {
                return unsafe __macro_local_5spansfMu0_(lhs.assumingMemoryBound(to: Swift.UInt8.self).span, rhs.assumingMemoryBound(to: Swift.UInt8.self).span)
              }
            }
            """
        }
    }
}
