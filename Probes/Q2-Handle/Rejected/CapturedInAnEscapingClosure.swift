import ISO_9075_Call_Level_Interface
import SQLite_Handle

// Capture of the handle in a closure that escapes, with no Task.
func capturedInAnEscapingClosure(_ connection: borrowing SQLite.Connection) -> () -> Void {
    connection.lend { (handle: borrowing SQLite.Handle) in
        return { _ = try? handle.execute("DELETE FROM item") }
    }
}
