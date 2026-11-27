import ISO_9075_Call_Level_Interface
import Lent_Interface
import SQLite_Actors
import SQLite_Handle

final class Tally { var count = 0 }

// A body cannot capture non-Sendable state of the caller's actor: that state stays with the actor, so it cannot be sent.
actor Caller {
    let tally = Tally()

    func write(_ database: SQLite.Database) async throws {
        let _: Int = try await database.write { connection throws(ISO.`9075`.Error) in
            self.tally.count = try connection.execute("DELETE FROM item")
            return self.tally.count
        }
    }
}
