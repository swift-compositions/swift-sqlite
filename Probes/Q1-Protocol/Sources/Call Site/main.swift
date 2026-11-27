import ISO_9075_Call_Level_Interface
import Lent_Interface

/// Not Sendable.
final class Tally {
    var count = 0
}

struct Refused: Swift.Error, Equatable {}

/// Reads and writes through `some Lent.Database`, with a capture and a result that are not Sendable.
func exercise(_ database: some Lent.Database) async throws {
    let captured = Tally()
    captured.count = 41

    // The general requirement: a typed throw of the caller's own, a non-Sendable capture, a non-Sendable result.
    let written: Tally = try await database.write { connection throws(Refused) in
        captured.count += 1
        let result = Tally()
        do {
            result.count = try connection.execute("INSERT \(raw: "\(captured.count)")")
        } catch {
            throw Refused()
        }
        return result
    }
    written.count += 100

    // The flattening overload: the body throws ISO_9075.Error, and so does the call.
    let read: [String] = try await database.read { connection throws(ISO.`9075`.Error) in
        try connection.fetchAll("SELECT") { row throws(ISO.`9075`.Error) in "\(try row.value(at: 0))" }
    }

    // The typed throw comes back as Failure<Refused>.body.
    do throws(ISO.`9075`.Failure<Refused>) {
        let _: Int = try await database.write { _ throws(Refused) in throw Refused() }
    } catch {
        guard case .body(Refused()) = error else { fatalError("expected .body, got \(error)") }
        print("typed throw: \(error)")
    }

    let executed = try await database.execute("DELETE")
    print("written.count = \(written.count), rows read = \(read.count), executed = \(executed)")
}

/// `any Lent.Database`, opened by a generic function. A call on the existential itself is a compiler error:
/// Rejected/ExistentialDatabase.swift.
func throughAnExistential(_ database: any Lent.Database) async throws {
    try await exercise(database)
}

try await exercise(Memory.Database())
try await throughAnExistential(Memory.Database())
