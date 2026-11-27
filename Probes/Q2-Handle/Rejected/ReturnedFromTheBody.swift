import ISO_9075_Call_Level_Interface
import SQLite_Handle

// The handle as the body's result.
func returnedFromTheBody(_ connection: borrowing SQLite.Connection) {
    connection.lend { (handle: borrowing SQLite.Handle) -> SQLite.Handle in
        return handle
    }
}
