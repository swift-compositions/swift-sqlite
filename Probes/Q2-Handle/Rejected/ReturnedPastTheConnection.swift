import ISO_9075_Call_Level_Interface
import SQLite_Handle

// The handle taken from the property, and returned from a function that owns the connection.
@_lifetime(immortal)
func returnedPastTheConnection() throws -> SQLite.Handle {
    let connection = try SQLite.Connection(path: ":memory:")
    return connection.handle
}
