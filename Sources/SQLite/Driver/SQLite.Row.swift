internal import SQLite_Shims
internal import Synchronization
public import ISO_9075_Call_Level_Interface
public import SQLite_SQL

extension SQLite {
    /// One row of a statement's result.
    ///
    /// While the statement is on this row, a value is read from SQLite when it is asked for: a column that nobody
    /// reads costs nothing. A row that is kept beyond its `decode` call is copied out of the statement first, so its
    /// values stay valid after the statement steps on.
    public struct Row: ISO.`9075`.Row, Sendable {
        public let columns: [String]
        let storage: Storage

        public func value(at index: Int) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
            guard columns.indices.contains(index) else { throw .decoding("no column \(index)") }
            return storage.value(at: index)
        }
    }
}

extension SQLite.Row {
    /// Where a row's values are: in the statement, while it is on the row, and in `kept` after ``keep()``.
    ///
    /// The connection that steps the statement holds one of these and gives it to each row in turn. After each
    /// `decode` call it asks whether the row is still held somewhere; only then are the values copied.
    ///
    /// Behind a lock, because a row is a value that may be sent: a row that was handed to another thread while the
    /// statement was on it is read there while the connection's thread copies it out.
    final class Storage: Sendable {
        private let state: Mutex<State>

        struct State {
            /// The address of the statement that is on this row, or 0 once the values are in `kept`.
            var statement: UInt
            let count: Int32
            var kept: [ISO.`9075`.Value] = []
        }

        @unsafe
        init(statement: OpaquePointer, count: Int32) {
            self.state = Mutex(State(statement: unsafe UInt(bitPattern: statement), count: count))
        }

        func value(at index: Int) -> ISO.`9075`.Value {
            state.withLock { state in
                guard let statement = unsafe OpaquePointer(bitPattern: state.statement) else { return state.kept[index] }
                return unsafe SQLite.Connection.Core.value(statement, Int32(index))
            }
        }

        /// Copies every value out of the statement. Called before the statement leaves the row.
        func keep() {
            state.withLock { state in
                guard let statement = unsafe OpaquePointer(bitPattern: state.statement) else { return }
                state.kept = (0..<state.count).map { unsafe SQLite.Connection.Core.value(statement, $0) }
                state.statement = 0
            }
        }
    }
}
