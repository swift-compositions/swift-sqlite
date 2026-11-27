import Followed
import Testing

let writes = 20_000
let priorities: [(TaskPriority, TaskPriority)] = [(.medium, .medium), (.low, .high), (.high, .low), (.background, .high)]

func configurations(_ isolation: Isolation, wait: Wait) -> [Configuration] {
    priorities.flatMap { listener, writers in
        [false, true].map { noise in
            Configuration(isolation: isolation, listener: listener, writers: writers, noise: noise, wait: wait)
        }
    }
}

// On Swift 6.4.2, Linux, the three barrier tests FAIL in every configuration: that is the answer to the question.
// Sources/Mechanism shows why. The acknowledgement tests and the control pass.
@Suite(.serialized)
struct Order {
    @Test(arguments: configurations(.main, wait: .barrier))
    func `barrier on the main actor`(_ configuration: Configuration) async {
        #expect(await breaks(configuration, writes: writes) == 0)
    }

    @Test(arguments: configurations(.default, wait: .barrier))
    func `barrier on a default actor`(_ configuration: Configuration) async {
        #expect(await breaks(configuration, writes: writes) == 0)
    }

    @Test(arguments: configurations(.thread, wait: .barrier))
    func `barrier on an actor with a thread executor`(_ configuration: Configuration) async {
        #expect(await breaks(configuration, writes: writes) == 0)
    }

    @Test(arguments: Isolation.allCases.flatMap { configurations($0, wait: .acknowledgement) })
    func `acknowledgement`(_ configuration: Configuration) async {
        #expect(await breaks(configuration, writes: writes) == 0)
    }

    /// The control: with no wait the order must break, or these tests could not see a break.
    @Test func `no wait breaks`() async {
        let configuration = Configuration(isolation: .default, listener: .medium, writers: .medium, noise: true, wait: .nothing)
        #expect(await breaks(configuration, writes: writes) > 0)
    }

    /// A listener that leaves its loop must not leave a write waiting for it.
    @Test func `acknowledgement, and the listener leaves`() async {
        let followed = Followed()
        let writer = Writer()
        let listener = Task {
            var seen = 0
            for await value in followed {
                seen = value
                if seen == 3 { break }
            }
            return seen
        }
        while !followed.isFollowed { await Task.yield() }
        for _ in 0..<10 { _ = await write(writer, followed, wait: .acknowledgement) }
        #expect(await listener.value == 3)
    }

    /// A listener whose task is cancelled must not leave a write waiting for it.
    @Test func `acknowledgement, and the listener is cancelled`() async {
        let followed = Followed()
        let writer = Writer()
        let listener = Task { for await _ in followed {} }
        while !followed.isFollowed { await Task.yield() }
        _ = await write(writer, followed, wait: .acknowledgement)
        listener.cancel()
        for _ in 0..<10 { _ = await write(writer, followed, wait: .acknowledgement) }
        await listener.value
    }
}
