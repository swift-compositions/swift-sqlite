import ISO_9075_Call_Level_Interface
import Lent_Interface

final class Tally { var count = 0 }

// The engine's side: a body's `sending` result must be disconnected from what the engine keeps. An engine that
// hands out state of its own actor as the result is rejected.
actor Engine {
    let kept = Tally()

    func run<Value>(_ body: sending (Tally) -> sending Value) -> sending Value { body(kept) }

    func leak() -> sending Tally { kept }
}
