public import ISO_9075_Call_Level_Interface
public import SQLite_Handle
internal import Lent_Interface
public import Thread_Actor

extension SQLite {
    /// One connection and the one thread that touches it: an actor of our own whose executor is a
    /// `Kernel.Thread.Executor`, the shape of `Kernel.Thread.Actor` with state beside the executor.
    ///
    /// The connection is a `~Copyable` stored property of the actor.
    public actor Worker {
        public nonisolated let executor: Kernel.Thread.Executor
        let connection: SQLite.Connection

        public init(path: Swift.String, executor: Kernel.Thread.Executor = .init()) throws(ISO.`9075`.Error) {
            self.executor = executor
            self.connection = try SQLite.Connection(path: path)
        }

        public nonisolated var unownedExecutor: UnownedSerialExecutor {
            unsafe executor.asUnownedSerialExecutor()
        }

        /// Runs `body` on this actor's thread, inside `begin` and `end`. The body comes in by `sending`, its result
        /// goes out by `sending`; neither is Sendable.
        public func run<Value, Thrown: Swift.Error>(
            begin: ISO.`9075`.Fragment,
            end: ISO.`9075`.Fragment,
            _ body: sending (borrowing SQLite.Handle) throws(Thrown) -> sending Value
        ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try connection.lend { (handle: borrowing SQLite.Handle) throws(ISO.`9075`.Failure<Thrown>) -> Value in
                do throws(ISO.`9075`.Error) {
                    _ = try handle.execute(begin)
                } catch {
                    throw .database(error)
                }
                let value: Value
                do throws(Thrown) {
                    value = try body(handle)
                } catch {
                    _ = try? handle.execute("ROLLBACK")
                    throw .body(error)
                }
                do throws(ISO.`9075`.Error) {
                    _ = try handle.execute(end)
                } catch {
                    throw .database(error)
                }
                return value
            }
        }
    }
}
