public import ISO_9075_Call_Level_Interface
public import SQLite_SQL

extension SQLite {
    /// One row of a result, kept: its column names and a copy of its values.
    ///
    /// ``fetchAll(_:_:)`` returns these, for a reader that wants whole rows. A fetch that decodes inside its `decode`
    /// call reads the connection's own row, ``SQLite/Connection/Row``, and copies nothing it does not ask for.
    public struct Row: ISO.`9075`.Row, Sendable {
        public let columns: [String]
        let values: [ISO.`9075`.Value]

        /// A copy of the row a connection lends.
        public init(_ row: borrowing SQLite.Connection.Row) {
            self.columns = row.columns
            self.values = row.values
        }

        public func value(at index: Int) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
            guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
            return values[index]
        }
    }
}
