public import SQLite_SQL
#if Observation
    internal import Dispatch
    package import GRDB

    extension SQLite {
        /// How an observed fetch (``FetchAll``, ``FetchOne``, ``Fetch``, ``FetchStore``) delivers its values: the first
        /// one, and each one a later write changes.
        public struct Scheduler: Sendable {
            package let driver: any ValueObservationScheduler

            package init(_ driver: any ValueObservationScheduler) {
                self.driver = driver
            }
        }
    }

    extension SQLite.Scheduler {
        /// The first value at once, on the main actor that starts the fetch; each later one on the main actor, as soon
        /// as it is read.
        public static var immediate: Self { Self(Immediate()) }
    }

    extension SQLite.Scheduler {
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

    #if canImport(SwiftUI)
        public import SwiftUI

        extension SQLite.Scheduler {
            /// As ``immediate``, with every later value delivered inside `animation`, as sqlite-data's
            /// `.animation(_:)` scheduler.
            public static func animation(_ animation: Animation?) -> Self { Self(Animated(animation: animation)) }

            struct Animated: ValueObservationScheduler {
                let animation: Animation?

                func immediateInitialValue() -> Bool { true }

                func schedule(_ action: @escaping @Sendable () -> Void) {
                    DispatchQueue.main.async {
                        withAnimation(animation) { action() }
                    }
                }
            }
        }
    #endif
#endif
