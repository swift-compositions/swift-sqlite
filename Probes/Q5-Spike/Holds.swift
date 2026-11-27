// swift-sqlite#25: the variation that holds (variation 6 of Spike.swift), alone, with a small check.
//
//   swiftc -swift-version 6 -parse-as-library -enable-upcoming-feature NonisolatedNonsendingByDefault Holds.swift -o holds
//   ./holds
//
// The mechanism is the one of the test clocks: swift-atoms/swift-clock (8174e46, `Clock.Test`: `sleep`, `advance`,
// `wake`) and pointfreeco/swift-clocks (branch clocks-2, 0ff28f7, `TestClock`: `sleep`, `advance`).

import Synchronization

/// A sequence of the numbers that are posted to it, for one listener. When `await post()` returns, the listener's
/// loop has run its body for that number, up to the body's first suspension.
final class Followed: AsyncSequence, Sendable {
    typealias Element = Int
    typealias Failure = Never

    private struct State {
        var buffer: [Int] = []
        var posted = 0
        var finished = false
        /// The isolation of the listener's last `next`.
        var isolation: (any Actor)?
        /// The listener's pending `next`.
        var waiter: CheckedContinuation<Int?, Never>?
        /// The waiter was resumed, and its `next` is not yet back on the listener's isolation.
        var transit = false
        /// The posters that wait for that.
        var acknowledgements: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())

    func makeAsyncIterator() -> Iterator { Iterator(followed: self) }

    struct Iterator: AsyncIteratorProtocol {
        let followed: Followed

        mutating func next() async -> Int? {
            await followed.next(isolation: #isolation)
        }

        mutating func next(isolation actor: isolated (any Actor)?) async -> Int? {
            await followed.next(isolation: actor)
        }
    }

    // The listener's side.

    func next(isolation actor: isolated (any Actor)?) async -> Int? {
        // A listener with no isolation cannot be waited for.
        precondition(actor != nil, "a followed read needs a listener on an actor")

        let value: Int? = await withCheckedContinuation { continuation in
            let ready: Int?? = state.withLock { state in
                state.isolation = actor
                // A number that is already there is returned with no suspension: its body runs in this job.
                if !state.buffer.isEmpty { return .some(state.buffer.removeFirst()) }
                if state.finished { return .some(nil) }
                state.waiter = continuation
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }

        // Here the listener is back on its isolation, and it keeps it until the loop's next suspension: the body
        // runs first. A poster that is resumed now must get this isolation to return, so it returns after the body.
        let acknowledgements = state.withLock { state in
            state.transit = false
            defer { state.acknowledgements = [] }
            return state.acknowledgements
        }
        for acknowledgement in acknowledgements { acknowledgement.resume() }
        return value
    }

    func finish() {
        let waiter = state.withLock { state in
            state.finished = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume(returning: nil)
    }

    // The poster's side.

    /// Posts the next number. Returns it when the listener has run its body for it.
    nonisolated(nonsending) func post() async -> Int {
        let (number, waiter, isolation) = state.withLock { state -> (Int, CheckedContinuation<Int?, Never>?, (any Actor)?) in
            state.posted += 1
            if let waiter = state.waiter {
                state.waiter = nil
                state.transit = true
                return (state.posted, waiter, state.isolation)
            }
            state.buffer.append(state.posted)
            return (state.posted, nil, state.isolation)
        }
        // No isolation: no listener has asked for a number yet.
        if let isolation { await acknowledge(on: isolation, resuming: waiter, with: number) }
        return number
    }

    /// Runs on the listener's isolation.
    ///
    /// With a waiter: stores the acknowledgement, and only then resumes the waiter. The suspension frees the
    /// isolation for the listener.
    ///
    /// With no waiter, the listener is in one of two places. In a job on its isolation: that job is over now,
    /// because this function runs on the same isolation, and the job took the number from the buffer. Or on its way
    /// back to its isolation after another poster resumed it: then this poster waits for the same acknowledgement.
    private func acknowledge(
        on actor: isolated any Actor,
        resuming waiter: CheckedContinuation<Int?, Never>?,
        with number: Int
    ) async {
        await withCheckedContinuation { (acknowledgement: CheckedContinuation<Void, Never>) in
            let wait = state.withLock { state in
                guard waiter != nil || state.transit else { return false }
                state.acknowledgements.append(acknowledgement)
                return true
            }
            waiter?.resume(returning: number)
            if !wait { acknowledgement.resume() }
        }
    }
}

// A small check. Spike.swift has the complete one: 90 configurations, three listeners for one post.

final class Seen: Sendable {
    private let value = Atomic<Int>(0)
    func record(_ seen: Int) { value.store(seen, ordering: .sequentiallyConsistent) }
    var last: Int { value.load(ordering: .sequentiallyConsistent) }
}

actor Listener {
    func listen(_ followed: Followed, _ seen: Seen) async {
        for await number in followed { seen.record(number) }
    }
}

@MainActor func listenOnMain(_ followed: Followed, _ seen: Seen) async {
    for await number in followed { seen.record(number) }
}

func breaks(onMain: Bool, posts: Int) async -> Int {
    let followed = Followed()
    let seen = Seen()
    let actor = Listener()
    let listener = Task.detached(priority: .low) {
        if onMain { await listenOnMain(followed, seen) } else { await actor.listen(followed, seen) }
    }
    let broken = await withTaskGroup(of: Int.self) { group in
        for priority in [TaskPriority.high, .medium, .low, .background] {
            group.addTask(priority: priority) {
                var broken = 0
                for _ in 0..<(posts / 4) {
                    let number = await followed.post()
                    // The first posts can come before the listener's first `next`: nobody listens yet.
                    if seen.last < number && seen.last > 0 { broken += 1 }
                }
                return broken
            }
        }
        var total = 0
        for await broken in group { total += broken }
        return total
    }
    followed.finish()
    await listener.value
    return broken
}

@main
enum Holds {
    static func main() async {
        print("default actor: \(await breaks(onMain: false, posts: 100_000)) breaks in 100000 posts")
        print("main actor:    \(await breaks(onMain: true, posts: 100_000)) breaks in 100000 posts")
    }
}
