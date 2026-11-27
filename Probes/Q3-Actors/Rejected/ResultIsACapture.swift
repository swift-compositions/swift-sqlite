import ISO_9075_Call_Level_Interface
import Lent_Interface
import SQLite_Actors
import SQLite_Handle

final class Tally { var count = 0 }

// A non-Sendable value that the body captured cannot be the body's `sending` result, even though the body itself was
// sent and the caller never touches the capture again. The body must return a value it made.
func resultIsACapture(_ database: SQLite.Database) async throws {
    let captured = Tally()
    let _: Tally = try await database.write { connection throws(ISO.`9075`.Error) in
        captured.count = try connection.execute("DELETE FROM item")
        return captured
    }
}
