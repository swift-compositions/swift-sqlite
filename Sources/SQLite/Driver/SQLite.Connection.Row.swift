public import Byte
internal import SQLite_Shims
public import ISO_9075_Call_Level_Interface
public import SQLite_SQL

extension SQLite.Connection {
    /// The row a connection lends to `decode`, while its statement is on that row.
    ///
    /// It reads SQLite's own memory: a value is read when it is asked for, and ``bytes(at:)`` and ``text(at:)`` give
    /// a blob and a text where SQLite holds them, with no copy. It is not escapable, so `decode` cannot return it,
    /// store it or capture it, and neither can a span leave: the statement steps on when `decode` returns. To keep
    /// a row, copy it: ``SQLite/Row/init(_:)``.
    @safe
    public struct Row: ISO.`9075`.Row, ~Escapable {
        public let columns: [String]
        private let statement: OpaquePointer
        private let count: Int32

        /// The row `statement` is on. The row depends on the connection that steps the statement.
        @unsafe
        @_lifetime(borrow core)
        init(_ core: borrowing SQLite.Connection.Core, statement: OpaquePointer, columns: [String]) {
            unsafe self.statement = statement
            self.columns = columns
            self.count = Int32(columns.count)
        }
    }
}

@available(*, unavailable)
extension SQLite.Connection.Row: Sendable {}

extension SQLite.Connection.Row {
    public func value(at index: Int) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
        unsafe SQLite.Connection.Core.value(statement, try column(index))
    }

    /// A copy of every value, in column order.
    var values: [ISO.`9075`.Value] {
        (0..<count).map { unsafe SQLite.Connection.Core.value(statement, $0) }
    }

    /// The bytes of the blob in column `index`, in SQLite's memory; `nil` for NULL. A column that holds anything but
    /// a blob throws: SQLite would convert it, and a conversion moves the bytes that an earlier span reads.
    @_lifetime(borrow self)
    public func bytes(at index: Int) throws(ISO.`9075`.Error) -> Span<Byte>? {
        let column = try column(index)
        switch unsafe sqlite3_column_type(statement, column) {
        case SQLITE_NULL: return nil
        case SQLITE_BLOB:
            let count = Int(unsafe sqlite3_column_bytes(statement, column))
            let start = unsafe sqlite3_column_blob(statement, column)?.assumingMemoryBound(to: Byte.self)
            // `Byte` is a frozen struct of one `UInt8`: SQLite's bytes are laid out as an array of them.
            let span = unsafe Span(_unsafeStart: start ?? UnsafePointer(bitPattern: 1)!, count: start == nil ? 0 : count)
            return unsafe _overrideLifetime(span, borrowing: self)
        default: throw .decoding("column \(index) holds no blob")
        }
    }

    /// The text in column `index`, in SQLite's memory; `nil` for NULL. A column that holds anything but text, or
    /// text that is not UTF-8, throws.
    @_lifetime(borrow self)
    public func text(at index: Int) throws(ISO.`9075`.Error) -> UTF8Span? {
        let column = try column(index)
        switch unsafe sqlite3_column_type(statement, column) {
        case SQLITE_NULL: return nil
        case SQLITE_TEXT:
            let start = unsafe sqlite3_column_text(statement, column)
            let count = Int(unsafe sqlite3_column_bytes(statement, column))
            let span = unsafe Span(_unsafeStart: start ?? UnsafePointer(bitPattern: 1)!, count: start == nil ? 0 : count)
            let text: UTF8Span
            do {
                text = try UTF8Span(validating: span)
            } catch {
                throw .decoding("column \(index) holds text that is not UTF-8")
            }
            return unsafe _overrideLifetime(text, borrowing: self)
        default: throw .decoding("column \(index) holds no text")
        }
    }

    private func column(_ index: Int) throws(ISO.`9075`.Error) -> Int32 {
        guard index >= 0, index < Int(count) else { throw .decoding("no column \(index)") }
        return Int32(index)
    }
}
