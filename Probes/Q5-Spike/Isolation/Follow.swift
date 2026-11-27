// swift-sqlite#25, case 2: can a listener on no actor be rejected at compile time?
//
// The requirement `next(isolation:)` of AsyncIteratorProtocol takes an optional actor, and a conformer cannot change
// that. The function that gives out the sequence can: its isolated parameter is not optional, and its default is the
// caller's isolation. The sequence is not Sendable, so it cannot go from the actor that asked for it to code with no
// actor. `check.sh` compiles each Accepted.* and Rejected.* file with this one.

final class Marker {}

/// Not Sendable: it stays in the region of the actor that asked for it.
struct Values: AsyncSequence {
    typealias Element = Int
    typealias Failure = Never
    let isolation: any Actor
    let marker = Marker()
    func makeAsyncIterator() -> Iterator { Iterator(isolation: isolation, marker: marker) }
    struct Iterator: AsyncIteratorProtocol {
        let isolation: any Actor
        let marker: Marker
        mutating func next() async -> Int? { nil }
        mutating func next(isolation actor: isolated (any Actor)?) async -> Int? { nil }
    }
}

final class Hub: Sendable {
    /// The isolated parameter is not optional, and its default is the caller's isolation.
    func follow(isolation: isolated any Actor = #isolation) -> Values { Values(isolation: isolation) }
}
