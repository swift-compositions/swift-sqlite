import ISO_9075_Call_Level_Interface
import Lent_Interface
import SQLite_Handle

/// Written against the protocol only: what any engine's handle can do.
func count(_ connection: borrowing some Lent.Connection & ~Copyable & ~Escapable) throws(ISO.`9075`.Error) -> Int {
    try connection.fetchAll("SELECT count(*) FROM item") { row throws(ISO.`9075`.Error) in
        guard case .int(let count) = try row.value(at: 0) else { throw .decoding("count") }
        return Int(count)
    }[0]
}

let connection = try SQLite.Connection(path: ":memory:")

let names: [String] = try connection.lend { handle throws(ISO.`9075`.Error) in
    _ = try handle.execute("CREATE TABLE item (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
    let inserted = try handle.execute("INSERT INTO item (name) VALUES (\(text: "first")), (\(text: "second"))")
    precondition(inserted == 2)
    let counted = try count(handle)
    precondition(counted == 2)
    return try handle.fetchAll("SELECT name FROM item ORDER BY id") { row throws(ISO.`9075`.Error) in
        guard case .text(let name) = try row.value(named: "name") else { throw .decoding("name") }
        return name
    }
}
print("lent, executed, fetched: \(names)")

// The handle as a local of the borrow's scope, without a closure.
do {
    let handle = connection.handle
    print("count through a local handle: \(try count(handle))")
}
