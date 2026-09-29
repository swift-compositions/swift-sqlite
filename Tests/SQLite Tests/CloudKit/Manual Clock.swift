#if CloudKit
    import GRDB
    import CloudKit
    import Synchronization

    final class ManualClock: Clock, Sendable {
        struct Instant: InstantProtocol {
            let offset: Duration

            func advanced(by duration: Duration) -> Self {
                Self(offset: offset + duration)
            }

            func duration(to other: Self) -> Duration {
                other.offset - offset
            }

            static func < (lhs: Self, rhs: Self) -> Bool {
                lhs.offset < rhs.offset
            }
        }

        private struct Sleeper {
            let id: Int
            let deadline: Instant
            let continuation: CheckedContinuation<Void, any Error>
        }

        private struct State {
            var now = Instant(offset: .zero)
            var nextID = 0
            var sleepers: [Sleeper] = []
        }

        private let state = Mutex(State())

        var now: Instant {
            state.withLock { $0.now }
        }

        var minimumResolution: Duration {
            .zero
        }

        func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
            let id = state.withLock { state in
                defer { state.nextID += 1 }
                return state.nextID
            }
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let resumption: Result<Void, any Error>? = state.withLock { state in
                        guard !Task.isCancelled else { return .failure(CancellationError()) }
                        guard deadline > state.now else { return .success(()) }
                        state.sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                        return nil
                    }
                    resumption.map { continuation.resume(with: $0) }
                }
            } onCancel: {
                state.withLock { state in
                    state.sleepers.firstIndex { $0.id == id }.map { state.sleepers.remove(at: $0) }
                }?
                .continuation
                .resume(throwing: CancellationError())
            }
        }

        func advance(by duration: Duration) async {
            state.withLock { state in
                state.now = state.now.advanced(by: duration)
                let due = state.sleepers.filter { $0.deadline <= state.now }
                state.sleepers.removeAll { $0.deadline <= state.now }
                return due
            }
            .forEach { $0.continuation.resume() }
            for _ in 0..<20 {
                await Task.detached(priority: .background) { await Task.yield() }.value
            }
        }
    }
#endif
