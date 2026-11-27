import ISO_9075_Call_Level_Interface
import SQLite_Handle

func requiresSendable<Value: Sendable & ~Copyable & ~Escapable>(_ value: borrowing Value) {}

// The handle is not Sendable.
func notSendable(_ connection: borrowing SQLite.Connection) {
    connection.lend { (handle: borrowing SQLite.Handle) in
        requiresSendable(handle)
    }
}
