import ISO_9075_Call_Level_Interface
import SQLite_Handle

// The same capture, with the parameter's ownership inferred (`{ handle in`). Swift 6.4.2 does not accept it, but it
// does not diagnose it either: the SIL ownership verifier stops the compiler. A `~Copyable` parameter alone is enough
// to see it; `~Escapable` is not needed.
func capturedInATask(_ connection: borrowing SQLite.Connection) {
    connection.lend { handle in
        Task { _ = try handle.execute("DELETE FROM item") }
        return ()
    }
}
