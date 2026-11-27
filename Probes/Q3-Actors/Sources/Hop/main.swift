import Executors
import Glibc
import ISO_9075_Call_Level_Interface
import Lent_Interface
import SQLite_Actors
import SQLite_Handle

/// Not Sendable.
final class Tally {
    var count = 0
    var thread: UInt = 0
}

struct Refused: Swift.Error, Equatable {}

func thread() -> UInt { UInt(pthread_self()) }

func count(_ connection: borrowing SQLite.Handle) throws(ISO.`9075`.Error) -> Int {
    try connection.fetchAll("SELECT count(*) FROM item") { row throws(ISO.`9075`.Error) in
        guard case .int(let count) = try row.value(at: 0) else { throw .decoding("count") }
        return Int(count)
    }[0]
}

actor Caller {
    var total = 0
    func write(_ database: SQLite.Database) async throws -> Int {
        let captured = Tally()
        let result: Tally = try await database.write { connection throws(ISO.`9075`.Error) in
            captured.count = try connection.execute("INSERT INTO item (name) VALUES (\(text: "caller"))")
            // Not `return captured`: a capture cannot be the `sending` result (Rejected/ResultIsACapture.swift).
            let result = Tally()
            result.count = captured.count
            return result
        }
        assertIsolated()
        total += result.count
        return total
    }
}

@MainActor
func probe() async throws {
    let path = "/tmp/q3-actors-\(getpid()).sqlite"
    defer { _ = unsafe unlink(path) }
    let database = try await SQLite.Database(path: path, readers: 2)

    // 1. From the main actor: the nonsending write hops to the writer's thread, runs the sending body there with a
    //    non-Sendable capture, and returns a non-Sendable result. The caller is back on the main actor.
    let captured = Tally()
    captured.count = 2
    let written: Tally = try await database.write { connection throws(ISO.`9075`.Error) in
        let onWriter = database.writer.executor.isIsolatingCurrentContext()
        precondition(onWriter == true, "the body is not on the writer's thread")
        _ = try connection.execute("CREATE TABLE item (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
        for index in 0..<captured.count { _ = try connection.execute("INSERT INTO item (name) VALUES (\(text: "\(index)"))") }
        let result = Tally()
        result.count = try count(connection)
        result.thread = thread()
        return result
    }
    MainActor.assertIsolated()
    // On Linux the main actor's jobs run on a Dispatch worker, so the thread is compared with the writer's only.
    precondition(written.thread != thread() && written.count == 2)
    written.count += 1  // ours now
    print("1. write from the main actor: body on thread \(written.thread), caller back on the main actor, thread \(thread())")

    // 2. Reads go to the readers' threads, each a thread of its own.
    var readers: Set<UInt> = []
    for _ in 0..<4 {
        let read: Tally = try await database.read { connection throws(ISO.`9075`.Error) in
            let result = Tally()
            result.count = try count(connection)
            result.thread = thread()
            return result
        }
        precondition(read.count == 2 && read.thread != written.thread && read.thread != thread())
        readers.insert(read.thread)
    }
    precondition(readers.count == 2)
    print("2. reads on \(readers.count) reader threads, none the writer's")

    // 3. From an actor of the default kind: the caller is back on that actor after the write.
    let total = try await Caller().write(database)
    precondition(total == 1)
    print("3. write from a default actor: caller back on its actor")

    // 4. The body's typed throw comes back as Failure<Refused>.body, and the transaction is rolled back.
    do throws(ISO.`9075`.Failure<Refused>) {
        let _: Int = try await database.write { connection throws(Refused) in
            _ = try? connection.execute("INSERT INTO item (name) VALUES (\(text: "refused"))")
            throw Refused()
        }
        fatalError("the write did not throw")
    } catch {
        guard case .body(Refused()) = error else { fatalError("\(error)") }
    }
    let afterRefusal = try await database.read { connection throws(ISO.`9075`.Error) in try count(connection) }
    precondition(afterRefusal == 3)
    print("4. typed throw: Failure<Refused>.body, and the insert was rolled back")

    // 5. Many writes at once from many tasks: one thread, one at a time.
    let threads = await withTaskGroup(of: UInt.self) { group in
        for index in 0..<200 {
            group.addTask {
                let result = try? await database.write { connection throws(ISO.`9075`.Error) in
                    _ = try connection.execute("INSERT INTO item (name) VALUES (\(text: "\(index)"))")
                    return thread()
                }
                return result ?? 0
            }
        }
        var threads: Set<UInt> = []
        for await thread in group { threads.insert(thread) }
        return threads
    }
    let afterGroup = try await database.read { connection throws(ISO.`9075`.Error) in try count(connection) }
    precondition(threads == [written.thread] && afterGroup == 203)
    print("5. 200 concurrent writes: all on the writer's thread, \(afterGroup) rows")

    // 6. swift-threads' own Kernel.Thread.Actor as the isolation, through an `isolated` parameter.
    let shared = try SQLite.Shared(path: ":memory:")
    let onActor: Tally = try await shared.write { connection throws(ISO.`9075`.Error) in
        let onActor = shared.executor.isIsolatingCurrentContext()
        precondition(onActor == true)
        _ = try connection.execute("CREATE TABLE item (id INTEGER PRIMARY KEY)")
        let result = Tally()
        result.thread = thread()
        return result
    }
    MainActor.assertIsolated()
    precondition(onActor.thread != thread())
    print("6. Kernel.Thread.Actor as an isolated parameter: body on thread \(onActor.thread)")
}

try await probe()
