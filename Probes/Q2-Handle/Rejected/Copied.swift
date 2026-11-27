import ISO_9075_Call_Level_Interface
import SQLite_Handle

// A second copy of the handle.
func copied(_ connection: borrowing SQLite.Connection) {
    connection.lend { (handle: borrowing SQLite.Handle) in
        let second = copy handle
        _ = try? second.execute("DELETE FROM item")
    }
}
