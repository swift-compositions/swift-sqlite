public import ISO_9075_Call_Level_Interface
public import SQLite_SQL

extension SQLite {
    /// One row of a statement's result, copied out of the statement: its values stay valid after the statement steps on.
    public struct Row: ISO.`9075`.Row {
        public let columns: [String]
        let values: [ISO.`9075`.Value]

        public func value(at index: Int) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
            guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
            return values[index]
        }
    }
}
