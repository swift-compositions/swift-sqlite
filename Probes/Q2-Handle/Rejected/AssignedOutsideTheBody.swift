import ISO_9075_Call_Level_Interface
import SQLite_Handle

// The handle stored in a struct that is itself not escapable, and that struct assigned to a variable outside the body.
struct Keeper: ~Copyable, ~Escapable {
    let handle: SQLite.Handle

    @_lifetime(copy handle)
    init(_ handle: consuming SQLite.Handle) { self.handle = handle }
}

func assignedOutsideTheBody(_ connection: borrowing SQLite.Connection) {
    var kept: Keeper?
    connection.lend { (handle: borrowing SQLite.Handle) in
        kept = Keeper(handle)
    }
    _ = kept
}
