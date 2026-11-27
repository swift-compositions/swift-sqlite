public import SQLite_SQL
#if Observation
    extension SQLite {
        /// How an observed fetch (``FetchAll``, ``FetchOne``, ``Fetch``, ``FetchStore``) takes each value a later write
        /// changes. The first value is taken as it is.
        ///
        /// A value is taken on the main actor, with no suspension, in the listener's loop: so when a write returns, the
        /// store holds what was written.
        public struct Scheduler: Sendable {
            /// Runs the change it is given, at once.
            package let deliver: @MainActor @Sendable (() -> Void) -> Void

            package init(_ deliver: @escaping @MainActor @Sendable (() -> Void) -> Void) {
                self.deliver = deliver
            }
        }
    }

    extension SQLite.Scheduler {
        /// Each value as it is read.
        public static var immediate: Self { Self { change in change() } }
    }

    #if canImport(SwiftUI)
        public import SwiftUI

        extension SQLite.Scheduler {
            /// As ``immediate``, with every later value taken inside `animation`, as sqlite-data's `.animation(_:)`
            /// scheduler.
            public static func animation(_ animation: Animation?) -> Self {
                Self { change in withAnimation(animation) { change() } }
            }
        }
    #endif
#endif
