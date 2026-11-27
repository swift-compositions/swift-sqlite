import Glibc
import ISO_9075_Call_Level_Interface
import Lent_Interface
import PostgreSQL
import PostgreSQL_Lent

/// Not Sendable.
final class Tally {
    var count = 0
    var names: [String] = []
}

struct Refused: Swift.Error, Equatable {}

/// The call site of Q1-Protocol, word for word what an engine-neutral caller writes: it names no engine.
func exercise(_ database: some Lent.Database) async throws -> Tally {
    let captured = Tally()
    captured.names = ["first", "second"]

    let written: Tally = try await database.write { connection throws(ISO.`9075`.Error) in
        _ = try connection.execute("CREATE TEMPORARY TABLE item (id SERIAL PRIMARY KEY, name TEXT NOT NULL) ON COMMIT DROP")
        for name in captured.names {
            captured.count += try connection.execute("INSERT INTO item (name) VALUES (\(text: name))")
        }
        let result = Tally()
        result.count = captured.count
        result.names = try connection.fetchAll("SELECT name FROM item ORDER BY id") { row throws(ISO.`9075`.Error) in
            guard case .text(let name) = try row.value(at: 0) else { throw .decoding("name") }
            return name
        }
        return result
    }
    written.count += 100

    do throws(ISO.`9075`.Failure<Refused>) {
        let _: Int = try await database.write { _ throws(Refused) in throw Refused() }
        fatalError("the write did not throw")
    } catch {
        guard case .body(Refused()) = error else { fatalError("\(error)") }
    }
    return written
}

guard let url = unsafe getenv("PROBE_POSTGRES").map({ unsafe String(cString: $0) }) else {
    print("PROBE_POSTGRES is not set: compiled, not run")
    exit(0)
}
let database = try PostgreSQL.Database(configuration: try PostgreSQL.Configuration(url: url))
let result = try await exercise(PostgreSQL.Lending(database))
precondition(result.count == 102 && result.names == ["first", "second"])
print("PostgreSQL through Lent.Database: count \(result.count), names \(result.names)")

// The same call site over the conformer whose connection is escapable.
let direct = try await exercise(PostgreSQL.Direct(database))
precondition(direct.count == 102)

// With that conformer the connection leaves the body: accepted by the compiler, and wrong at run time.
let escaped: PostgreSQL.Connection = try await PostgreSQL.Direct(database).read { connection throws(ISO.`9075`.Error) in
    copy connection
}
_ = escaped
print("PostgreSQL.Direct: the same call site passes, and a body can return the connection")
await database.close()
