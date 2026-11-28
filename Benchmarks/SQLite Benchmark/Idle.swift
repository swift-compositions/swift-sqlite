import Executors
import Thread_Actor

/// An actor on a thread of its own, as the driver's connections are, that counts.
actor Idle {
    nonisolated let executor = Kernel.Thread.Executor()
    nonisolated var unownedExecutor: UnownedSerialExecutor { unsafe executor.asUnownedSerialExecutor() }
    var count = 0

    func work(_ rounds: Int) -> Int {
        for round in 0..<rounds { count = (count &* 31) &+ round }
        count &+= 1
        return count
    }
}
