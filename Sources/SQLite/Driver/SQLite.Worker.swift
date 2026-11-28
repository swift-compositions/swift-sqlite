internal import ISO_9075_Call_Level_Interface
internal import SQLite_SQL
internal import Synchronization
internal import Thread_Actor

extension SQLite {
    /// One connection and the one thread that runs asynchronous reads or writes on it: an actor whose executor is a
    /// thread of its own. A read or a write hops here, so SQLite's blocking calls never hold a thread of the
    /// cooperative pool, and the calls on one connection queue in order.
    actor Worker {
        nonisolated let executor: Kernel.Thread.Executor
        nonisolated let slot: SQLite.Connection.Slot

        /// The worker that copies the log back beside this one, which is then the writer; `nil` when the
        /// configuration does not ask for it.
        private let checkpointer: Worker?

        /// The copy of the log that runs on ``checkpointer``; `nil` when none runs.
        private var copying: Task<Void, Never>?

        init(slot: SQLite.Connection.Slot, checkpointer: Worker? = nil) {
            self.executor = Kernel.Thread.Executor()
            self.slot = slot
            self.checkpointer = checkpointer
        }

        nonisolated var unownedExecutor: UnownedSerialExecutor {
            unsafe executor.asUnownedSerialExecutor()
        }

        func run<Value, Thrown: Swift.Error>(
            _ scope: SQLite.Connection.Slot.Scope,
            publishing receipt: SQLite.Hub.Receipt? = nil,
            _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
        ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            defer {
                if let checkpointer, let threshold = slot.threshold, copying == nil,
                    slot.logged.load(ordering: .relaxed) >= threshold
                {
                    copying = Task {
                        await checkpointer.checkpoint()
                        self.copying = nil
                    }
                }
            }
            return try slot.run(scope, publishing: receipt, body)
        }

        private func checkpoint() {
            slot.checkpoint()
        }

        /// Returns when no copy of the log that a write on this worker started is running.
        func settled() async {
            while let copying { await copying.value }
        }

        func restore(from source: SQLite.Connection.Slot) throws(SQLite.Error) {
            try slot.restore(from: source)
        }
    }
}
