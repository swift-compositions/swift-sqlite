// A handle that borrows a stored property of an actor directly, inside a method of that actor.
// A local `let log = self.log` first is accepted (Sources/Lent Interface/Memory.swift).
final class Log { var statements: [String] = [] }

struct Handle: ~Copyable, ~Escapable {
    let log: Log
    @_lifetime(borrow log)
    init(_ log: borrowing Log) { self.log = copy log }
}

actor Engine {
    let log = Log()

    func run<Value>(_ body: sending (borrowing Handle) -> sending Value) -> sending Value {
        let handle = Handle(log)
        return body(handle)
    }
}
