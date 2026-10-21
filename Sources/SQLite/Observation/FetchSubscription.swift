#if Observation
    public import Synchronization

    /// A subscription associated with `@FetchAll`, `@FetchOne`, and `@Fetch` observation.
    ///
    /// This value can be useful in associating the lifetime of observing a query to the lifetime of a
    /// SwiftUI view _via_ the `task` view modifier. For example, loading a query in a view's `task`
    /// will automatically cancel the observation when drilling down into a child view, and restart
    /// observation when popping back to the view:
    ///
    /// ```swift
    /// .task {
    ///   try? await $reminders.load(Reminder.all, database: database).task
    /// }
    /// ```
    public struct FetchSubscription: Sendable {
        private let cancellable = Cancellable()
        private let onCancel: @Sendable () -> Void

        @MainActor
        init<Value>(store: FetchStore<Value>) {
            onCancel = { Task { @MainActor in store.cancel() } }
        }

        /// An async handle to the given fetch observation.
        ///
        /// This handle will suspend until the current task is cancelled, at which point it will terminate
        /// the observation of the associated ``FetchAll``, ``FetchOne``, or ``Fetch``.
        public var task: Void {
            get async throws {
                let onCancel = onCancel
                let task = Task {
                    let (never, waiting) = AsyncStream<Never>.makeStream()
                    await withTaskCancellationHandler {
                        for await _ in never {}
                    } onCancel: {
                        waiting.finish()
                        onCancel()
                    }
                    try Task.checkCancellation()
                }
                cancellable.task.withLock { $0 = task }
                try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
            }
        }

        /// Cancels the database observation of the associated ``FetchAll``, ``FetchOne``, or ``Fetch``.
        public func cancel() {
            cancellable.task.withLock { $0 }?.cancel()
        }
    }

    extension FetchSubscription {
        /// The handle's task, shared by every copy of the subscription.
        private final class Cancellable: Sendable {
            let task = Mutex<Task<Void, any Swift.Error>?>(nil)
        }
    }
#endif
