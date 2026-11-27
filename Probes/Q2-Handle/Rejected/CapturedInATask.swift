import ISO_9075_Call_Level_Interface
import SQLite_Handle

// Capture of the handle in a Task. The closure states its parameter as `borrowing`: with the ownership left to
// inference the compiler crashes (CapturedInATask.InferredParameter.swift).
func capturedInATask(_ connection: borrowing SQLite.Connection) {
    connection.lend { (handle: borrowing SQLite.Handle) in
        Task { _ = try handle.execute("DELETE FROM item") }
        return ()
    }
}
