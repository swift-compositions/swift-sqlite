public import SQLite_SQL
#if Observation
    public import ISO_9075_Call_Level_Interface
    public import Observation

    /// The value of a request, kept up to date: the value when the store started, then the value each later write
    /// leaves.
    ///
    /// When a write returns, every store that follows the database holds what was written: the write waits for the
    /// store's loop on the main actor. A request whose value is `Equatable` changes the store only when its value does.
    @MainActor
    @Observable
    public final class FetchStore<Value: Sendable> {
        public private(set) var value: Value
        public private(set) var loadError: ISO.`9075`.Error?
        public private(set) var isLoading = false

        /// One fetch of the request: its value, or the error reading it gave. A read that fails is an answer, so the
        /// store keeps following after it.
        typealias Answer = Result<Value, ISO.`9075`.Error>

        /// The loop over the followed read. It is the only task that asks the read for its next answer.
        @ObservationIgnored
        private var following: Task<Void, Never>?

        /// Counts the starts, so that a start that was replaced while it waited knows it.
        @ObservationIgnored
        private var generation = 0

        public init(value: Value) {
            self.value = value
        }

        public convenience init(
            value: Value,
            _ request: some FetchKeyRequest<Value>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) {
            self.init(value: value)
            start(request, database: database, scheduling: scheduler)
        }

        isolated deinit {
            following?.cancel()
        }

        /// Replaces the value with the request's and follows it, as sqlite-data's `load`: returns once the first value
        /// is in, or throws its error; the observation lasts until ``cancel()`` or the returned subscription is cancelled.
        @discardableResult
        public func load(
            _ request: some FetchKeyRequest<Value>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) async throws -> FetchSubscription {
            let generation = begin()
            let followed: (first: Answer, later: SQLite.Observation<Answer>)
            do {
                followed = try await database.following(same: Self.same, Self.body(request))
            } catch {
                // Read again after the wait: another start may have replaced this one.
                guard generation == self.generation else { throw CancellationError() }
                isLoading = false
                loadError = error
                throw error
            }
            guard generation == self.generation else { throw CancellationError() }
            receive(followed.first)
            follow(followed.later, scheduling: scheduler)
            if let loadError { throw loadError }
            return FetchSubscription(store: self)
        }

        /// Starts following the request with its first value in on return, as the property wrappers do. The first
        /// value is read on the writer, on the caller's thread: it waits for a write that is running.
        func start(
            _ request: some FetchKeyRequest<Value>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) {
            _ = begin()
            do throws(ISO.`9075`.Error) {
                let followed = try database.following(on: MainActor.shared, same: Self.same, Self.body(request))
                receive(followed.first)
                follow(followed.later, scheduling: scheduler)
            } catch {
                isLoading = false
                loadError = error
            }
        }

        public func cancel() {
            generation += 1
            following?.cancel()
            following = nil
            isLoading = false
        }

        private func begin() -> Int {
            following?.cancel()
            following = nil
            generation += 1
            isLoading = true
            return generation
        }

        private func follow(_ answers: SQLite.Observation<Answer>, scheduling scheduler: SQLite.Scheduler) {
            following = Task { [weak self] in
                do throws(ISO.`9075`.Error) {
                    for try await answer in answers {
                        guard let self else { return }
                        // Taken here, with no suspension: the write that waits returns after it.
                        scheduler.deliver { self.receive(answer) }
                    }
                } catch {
                    self?.loadError = error
                }
            }
        }

        private func receive(_ answer: Answer) {
            isLoading = false
            switch answer {
            case .success(let value):
                self.value = value
                loadError = nil
            case .failure(let error):
                loadError = error
            }
        }
    }

    extension FetchStore {
        nonisolated static func body(
            _ request: some FetchKeyRequest<Value>
        ) -> @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Answer {
            { (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Answer in
                do throws(ISO.`9075`.Error) {
                    return .success(try request.fetch(connection))
                } catch {
                    return .failure(error)
                }
            }
        }

        /// Whether two answers are the same, for a value that is `Equatable`; `nil` for one that is not, and then
        /// every commit is an answer. Two errors are never the same.
        nonisolated static var same: (@Sendable (Answer, Answer) -> Bool)? {
            guard let equatable = Value.self as? any Equatable.Type else { return nil }
            return comparison(equatable)
        }

        private nonisolated static func comparison<Compared: Equatable>(
            _: Compared.Type
        ) -> @Sendable (Answer, Answer) -> Bool {
            { old, new in
                guard case .success(let old) = old, case .success(let new) = new else { return false }
                // Value is Compared: `comparison` is called with Value's own type.
                guard let old = old as? Compared, let new = new as? Compared else { return false }
                return old == new
            }
        }
    }

    #if canImport(SwiftUI)
        public import SwiftUI

        extension FetchStore {
            /// ``load(_:database:scheduling:)`` with every change delivered inside `animation`, as sqlite-data's
            /// `load(_:database:animation:)`.
            @discardableResult
            public func load(
                _ request: some FetchKeyRequest<Value>,
                database: SQLite.Database,
                animation: Animation?
            ) async throws -> FetchSubscription {
                try await load(request, database: database, scheduling: .animation(animation))
            }
        }
    #endif
#endif
