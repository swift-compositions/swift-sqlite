#if Observation
    public import GRDB
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

        public init(value: Value) {
            self.value = value
        }

        public convenience init(
            value: Value,
            _ request: some FetchKeyRequest<Value>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) {
            self.init(value: value)
            load(request, database: database, scheduling: scheduler)
        }

        public func load(
            _ request: some FetchKeyRequest<Value>,
            database: some DatabaseReader,
            scheduling scheduler: some ValueObservationScheduler = .immediate
        ) {
            cancellable?.cancel()
            isLoading = true
            cancellable = ValueObservation
                .tracking { database in
                    Result { () throws(ISO_9075.Error) -> Value in
                        do {
                            return try request.fetch(database)
                        } catch let error as ISO_9075.Error {
                            throw error
                        } catch {
                            throw .execution("\(error)")
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
        }

        private func receive(_ result: Result<Value, ISO_9075.Error>) {
            isLoading = false
            switch result {
            case .success(let value):
                self.value = value
                loadError = nil
            case .failure(let error):
                loadError = error
            }
        }
    }

    #if canImport(SwiftUI)
        public import SwiftUI

        public struct AnimatedScheduler: ValueObservationScheduler {
            let animation: Animation?

            public func immediateInitialValue() -> Bool { true }

            public func schedule(_ action: @escaping @Sendable () -> Void) {
                DispatchQueue.main.async {
                    withAnimation(animation) { action() }
                }
            }
        }

        extension ValueObservationScheduler where Self == AnimatedScheduler {
            public static func animation(_ animation: Animation?) -> Self {
                AnimatedScheduler(animation: animation)
            }
        }
    #endif
#endif
