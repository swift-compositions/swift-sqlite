import Followed

let writes = CommandLine.arguments.dropFirst().first.flatMap { Int($0) } ?? 20_000
let priorities: [(TaskPriority, TaskPriority)] = [(.medium, .medium), (.low, .high), (.high, .low), (.background, .high)]

print("writes per configuration: \(writes); a break is a write that returned before the listener's body ran for it")
for wait in Wait.allCases {
    for isolation in Isolation.allCases {
        for (listener, writers) in priorities {
            for noise in [false, true] {
                let configuration = Configuration(
                    isolation: isolation, listener: listener, writers: writers, noise: noise, wait: wait)
                let broken = await breaks(configuration, writes: writes)
                print("\(broken == 0 ? "holds " : "BREAKS") \(broken)\t\(configuration)")
            }
        }
    }
}
