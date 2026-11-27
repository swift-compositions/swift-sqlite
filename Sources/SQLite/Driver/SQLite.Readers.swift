internal import SQLite_Shims
internal import SQLite_SQL
internal import Synchronization

extension SQLite {
    /// The reader actors of a database with a file. Each opens when a read finds every open one in use, up to the
    /// configuration's count; after that a read queues on the one with the fewest reads.
    final class Readers: Sendable {
        private let path: String
        private let configuration: SQLite.Configuration
        private let state = Mutex(State())

        init(path: String, configuration: SQLite.Configuration) {
            self.path = path
            self.configuration = configuration
        }

        struct State {
            var workers: [SQLite.Worker] = []
            var load: [Int] = []
            var closed = false
        }

        struct Lease {
            let worker: SQLite.Worker
            let index: Int
        }
    }
}

extension SQLite.Readers {
    static func slot(path: String, configuration: SQLite.Configuration) throws(SQLite.Error) -> SQLite.Connection.Slot {
        try SQLite.Connection.Slot(path: path, flags: SQLITE_OPEN_READONLY, configuration: configuration, journal: .asFound)
    }

    func lease() throws(SQLite.Error) -> Lease {
        try state.withLock { state throws(SQLite.Error) in
            guard !state.closed else { throw .closed }
            if let idle = state.load.firstIndex(of: 0) {
                state.load[idle] += 1
                return Lease(worker: state.workers[idle], index: idle)
            }
            if state.workers.count < max(1, configuration.maximumReaderCount) {
                let worker = SQLite.Worker(slot: try Self.slot(path: path, configuration: configuration))
                state.workers.append(worker)
                state.load.append(1)
                return Lease(worker: worker, index: state.workers.count - 1)
            }
            let least = state.load.indices.min { state.load[$0] < state.load[$1] } ?? 0
            state.load[least] += 1
            return Lease(worker: state.workers[least], index: least)
        }
    }

    func release(_ lease: Lease) {
        state.withLock { state in
            if state.load.indices.contains(lease.index) { state.load[lease.index] -= 1 }
        }
    }

    func close() {
        let workers = state.withLock { state in
            state.closed = true
            return state.workers
        }
        for worker in workers { worker.slot.close() }
    }
}
