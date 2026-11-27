public import ISO_9075_Call_Level_Interface
public import Lent_Interface
public import PostgreSQL
public import PostgreSQL_SQL

// 1. swift-postgresql's connection as it is today, a copyable, escapable, Sendable struct, conforms to the protocol
//    whose conformers may be neither: nothing to write.
extension PostgreSQL.Connection: @retroactive Lent.Connection {}

// 2. The same guarantee as SQLite's handle: a view of the connection that cannot outlive the body.
extension PostgreSQL {
    public struct Handle: Lent.Connection, ~Copyable, ~Escapable {
        public var dialect: PostgreSQL { connection.dialect }
        let connection: PostgreSQL.Connection

        @_lifetime(borrow connection)
        init(_ connection: borrowing PostgreSQL.Connection) {
            self.connection = copy connection
        }

        public func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int {
            try connection.execute(statement)
        }

        public func fetchAll<Value>(
            _ statement: ISO.`9075`.Rendering,
            decode: (PostgreSQL.Row) throws(ISO.`9075`.Error) -> Value
        ) throws(ISO.`9075`.Error) -> [Value] {
            try connection.fetchAll(statement, decode: decode)
        }
    }
}
