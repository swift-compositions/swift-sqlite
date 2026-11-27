import ISO_9075_Call_Level_Interface
import SQLite_Handle

func close(_ connection: consuming SQLite.Connection) {}

// The connection given away while a handle on it is alive.
func connectionConsumedWhileLent() throws {
    let connection = try SQLite.Connection(path: ":memory:")
    let handle = connection.handle
    close(connection)
    _ = try handle.execute("DELETE FROM item")
}
