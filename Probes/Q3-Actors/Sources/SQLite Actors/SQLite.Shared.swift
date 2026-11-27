public import ISO_9075_Call_Level_Interface
public import SQLite_Handle
public import Thread_Actor

extension SQLite {
    /// The same hop with swift-threads' own `Kernel.Thread.Actor` as the isolation, and the connection in a box that
    /// only that actor may open: the function takes the actor as an `isolated` parameter.
    public final class Shared: @unchecked Sendable {
        public let actor: Kernel.Thread.Actor
        let connection: SQLite.Connection

        public init(path: Swift.String) throws(ISO.`9075`.Error) {
            self.actor = Kernel.Thread.Actor(executor: .init())
            self.connection = try SQLite.Connection(path: path)
        }

        public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing SQLite.Handle) throws(Thrown) -> sending Value
        ) async throws(Thrown) -> sending Value {
            try await run(on: actor, body)
        }

        func run<Value, Thrown: Swift.Error>(
            on actor: isolated Kernel.Thread.Actor,
            _ body: sending (borrowing SQLite.Handle) throws(Thrown) -> sending Value
        ) throws(Thrown) -> sending Value {
            try connection.lend(body)
        }
    }
}
