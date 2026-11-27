import ISO_9075_Call_Level_Interface
import Lent_Interface
import PostgreSQL
import PostgreSQL_Lent

// With the handle as the conformer's connection, the connection cannot be the body's result.
func handleReturned(_ database: PostgreSQL.Lending) async throws {
    try await database.read { (connection: borrowing PostgreSQL.Handle) throws(ISO.`9075`.Error) -> PostgreSQL.Handle in
        return connection
    }
}
