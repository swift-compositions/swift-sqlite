#if Observation
#if canImport(SwiftUI)
  package import GRDB
  import Sharing
  package import SwiftUI

  extension SharedReaderKey {
    static func fetch<Value>(
      _ request: some FetchKeyRequest<Value>,
      database: (any DatabaseReader)? = nil,
      animation: Animation?
    ) -> Self
    where Self == FetchKey<Value> {
      .fetch(request, database: database, scheduler: .animation(animation))
    }

    static func fetch<Records: RangeReplaceableCollection>(
      _ request: some FetchKeyRequest<Records>,
      database: (any DatabaseReader)? = nil,
      animation: Animation?
    ) -> Self
    where Self == FetchKey<Records>.Default {
      .fetch(request, database: database, scheduler: .animation(animation))
    }
  }

  package struct AnimatedScheduler: ValueObservationScheduler, Equatable {
    let animation: Animation?
    package func immediateInitialValue() -> Bool { true }
    package func schedule(_ action: @escaping @Sendable () -> Void) {
      DispatchQueue.main.async {
        withAnimation(animation) {
          action()
        }
      }
    }
  }

  extension AnimatedScheduler: Hashable {}

  extension ValueObservationScheduler where Self == AnimatedScheduler {
    package static func animation(_ animation: Animation?) -> Self {
      AnimatedScheduler(animation: animation)
    }
  }
#endif

#endif
