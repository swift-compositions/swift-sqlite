import ISO_9075_Call_Level_Interface
import SQLite_Handle

// The handle as the body's result, where the lending function lets the result be non-copyable and non-escapable.
// Even then a borrowed handle cannot be the result.
@_lifetime(borrow connection)
func lend<Value: ~Copyable & ~Escapable>(
    _ connection: borrowing SQLite.Connection,
    _ body: (borrowing SQLite.Handle) -> Value
) -> Value {
    body(connection.handle)
}

func returnedFromTheBody(_ connection: borrowing SQLite.Connection) {
    let escaped = lend(connection) { (handle: borrowing SQLite.Handle) -> SQLite.Handle in
        return handle
    }
    _ = try? escaped.execute("DELETE FROM item")
}
