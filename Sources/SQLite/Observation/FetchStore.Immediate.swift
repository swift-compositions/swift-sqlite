#if Observation
    internal import Dispatch
    public import GRDB

    extension FetchStore {
        /// GRDB's immediate scheduler, checked against the main actor instead of the main thread.
        ///
        /// A fetch store is main-actor isolated, so it starts its observation on the main actor. GRDB's
        /// `.immediate` scheduler requires the main thread, which is not the same thing: on Linux the main actor
        /// can run on a thread other than the process's initial one, and the check then fails although the
        /// caller is correctly isolated. Later values still arrive on the main queue, as GRDB delivers them.
        struct Immediate: ValueObservationMainActorScheduler {
            func immediateInitialValue() -> Bool {
                MainActor.preconditionIsolated("A fetch store starts its observation on the main actor")
                return true
            }

            func scheduleOnMainActor(_ action: @escaping @MainActor () -> Void) {
                DispatchQueue.main.async(execute: action)
            }
        }
    }
#endif
