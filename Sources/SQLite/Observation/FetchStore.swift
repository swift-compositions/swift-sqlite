#if Observation
    internal import GRDB
    public import ISO_9075_Call_Level_Interface
    public import Observation

    @MainActor
    @Observable
    public final class FetchStore<Value: Sendable> {
        public private(set) var value: Value
        public private(set) var loadError: ISO_9075.Error?
        public private(set) var isLoading = false

        @ObservationIgnored
        private var cancellable: AnyDatabaseCancellable?

        /// The awaited `load`, until the first value or error arrives.
        @ObservationIgnored
        private var loading: CheckedContinuation<Void, any Swift.Error>?

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

        /// Replaces the value with the request's and follows it, as sqlite-data's `load`: returns once the first value
        /// is in, or throws its error; the observation lasts until ``cancel()`` or the returned subscription is cancelled.
        @discardableResult
        public func load(
            _ request: some FetchKeyRequest<Value>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) async throws -> FetchSubscription {
            try await withCheckedThrowingContinuation { continuation in
                loading?.resume(throwing: CancellationError())
                loading = continuation
                start(request, database: database, scheduling: scheduler)
            }
            return FetchSubscription(store: self)
        }

        /// Starts following the request without waiting for its first value, as the property wrappers do.
        func start(
            _ request: some FetchKeyRequest<Value>,
            database: SQLite.Database,
            scheduling scheduler: SQLite.Scheduler = .immediate
        ) {
            cancellable?.cancel()
            isLoading = true
            cancellable = observe(request, database: database.writer, scheduling: scheduler.driver)
        }

        private func observe(
            _ request: some FetchKeyRequest<Value>,
            database: any DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler
        ) -> AnyDatabaseCancellable {
            ValueObservation
                .tracking { database in
                    Result { () throws(ISO_9075.Error) -> Value in
                        do {
                            return try request.fetch(SQLite.Connection(database))
                        } catch let error as ISO_9075.Error {
                            throw error
                        } catch {
                            throw .execution("\(SQLite.Error.translated(error))")
                        }
                    }
                }
                .start(in: database, scheduling: scheduler) { [weak self] error in
                    MainActor.assumeIsolated { self?.receive(.failure(.execution("\(error)"))) }
                } onChange: { [weak self] result in
                    MainActor.assumeIsolated { self?.receive(result) }
                }
        }

        public func cancel() {
            cancellable?.cancel()
            cancellable = nil
            isLoading = false
            loading?.resume(throwing: CancellationError())
            loading = nil
        }

        private func receive(_ result: Result<Value, ISO_9075.Error>) {
            isLoading = false
            switch result {
            case .success(let value):
                self.value = value
                loadError = nil
                loading?.resume()
            case .failure(let error):
                loadError = error
                loading?.resume(throwing: error)
            }
            loading = nil
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
