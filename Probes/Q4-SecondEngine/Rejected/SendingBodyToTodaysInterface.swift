import ISO_9075_Call_Level_Interface
import PostgreSQL

final class Tally { var count = 0 }

// Why PostgreSQL.Lending needs its unchecked box: a `sending` body with a non-Sendable capture cannot be given to
// the `@Sendable` body of today's `ISO_9075.Database`.
func sendingBody<Database: ISO.`9075`.Database>(
    _ database: Database,
    _ body: sending @escaping (Database.Connection) throws(ISO.`9075`.Error) -> Int
) async throws -> Int {
    try await database.write { connection throws(ISO.`9075`.Error) in try body(connection) }
}
