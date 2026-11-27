internal import ISO_9075_Call_Level_Interface
internal import SQLite_SQL
internal import Thread_Actor

extension SQLite {
    /// One connection and the one thread that runs asynchronous reads or writes on it: an actor whose executor is a
    /// thread of its own. A read or a write hops here, so SQLite's blocking calls never hold a thread of the
    /// cooperative pool, and the calls on one connection queue in order.
    actor Worker {
        nonisolated let executor: Kernel.Thread.Executor
        nonisolated let slot: SQLite.Connection.Slot

        init(slot: SQLite.Connection.Slot) {
            self.executor = Kernel.Thread.Executor()
            self.slot = slot
        }

        nonisolated var unownedExecutor: UnownedSerialExecutor {
            unsafe executor.asUnownedSerialExecutor()
        }

        func run<Value, Thrown: Swift.Error>(
            _ scope: SQLite.Connection.Slot.Scope,
            _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
        ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try slot.run(scope, body)
        }

        func restore(from source: SQLite.Connection.Slot) throws(SQLite.Error) {
            try slot.restore(from: source)
        }
    }
}
