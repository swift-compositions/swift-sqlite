import ISO_9075_Call_Level_Interface
import Lent_Interface

// Through the protocol alone, with no knowledge of the engine: the connection cannot be the body's result, because
// `Value` is an ordinary generic parameter, copyable and escapable.
func connectionReturned<Database: Lent.Database>(_ database: Database) async throws {
    try await database.write { (connection: borrowing Database.Connection) throws(ISO.`9075`.Error) -> Database.Connection in
        return connection
    }
}
