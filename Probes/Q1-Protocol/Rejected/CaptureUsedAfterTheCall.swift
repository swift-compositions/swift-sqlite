import ISO_9075_Call_Level_Interface
import Lent_Interface

final class Tally { var count = 0 }

// A non-Sendable capture of a `sending` body is gone from the caller: using it after the call is rejected.
func captureUsedAfterTheCall(_ database: some Lent.Database) async throws {
    let captured = Tally()
    let _: Int = try await database.write { _ throws(ISO.`9075`.Error) in
        captured.count += 1
        return captured.count
    }
    captured.count += 1
}
