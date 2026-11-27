import Glibc
import Synchronization

// Why the barrier does not hold: where does a resumed continuation's task go?
//
// A serial executor that records, for each job it is given, the thread that gave it. The listener awaits a
// continuation on an actor with this executor. The resumer calls `resume` on a thread of its own and records that
// thread. If `resume` enqueued the listener's task on the listener's executor, the job would arrive from the
// resumer's thread, inside the call to `resume`. It does not: it arrives later, from a thread of the global pool,
// because a continuation resumes its task on the global executor, and the task hops to its actor from there.

func thread() -> UInt { UInt(pthread_self()) }

final class Recording: SerialExecutor, Sendable {
    let jobs = Mutex<[UnownedJob]>([])
    let arrivals = Mutex<[(from: UInt, duringResume: Bool)]>([])
    let resuming = Atomic<UInt>(0)
    let wake = Mutex<Bool>(false)

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        arrivals.withLock { $0.append((thread(), resuming.load(ordering: .sequentiallyConsistent) == thread())) }
        jobs.withLock { $0.append(job) }
    }

    /// Runs the jobs, in the order they arrived, on the calling thread, until `done`.
    func run(until done: borrowing Atomic<Bool>) {
        while !done.load(ordering: .sequentiallyConsistent) {
            let next = jobs.withLock { $0.isEmpty ? nil : $0.removeFirst() }
            if let next { unsafe next.runSynchronously(on: asUnownedSerialExecutor()) } else { usleep(50) }
        }
    }
}

actor Listener {
    nonisolated let executor = Recording()
    nonisolated var unownedExecutor: UnownedSerialExecutor { unsafe executor.asUnownedSerialExecutor() }
    var waiter: CheckedContinuation<Int, Never>?
    var seen = 0

    func listen(parked: Parked) async {
        let value = await withCheckedContinuation { waiter = $0; parked.set() }
        seen = value
    }

    func take() -> CheckedContinuation<Int, Never>? { waiter }
    func barrier() -> Int { seen }
}

final class Parked: Sendable {
    let flag = Atomic<Bool>(false)
    func set() { flag.store(true, ordering: .sequentiallyConsistent) }
}

let listener = Listener()
let done = Atomic<Bool>(false)
// The listener's executor runs on a thread of its own.
let runner = Thread2 { listener.executor.run(until: done) }

let parked = Parked()
let listening = Task { await listener.listen(parked: parked) }
while !parked.flag.load(ordering: .sequentiallyConsistent) { await Task.yield() }
let waiter = await listener.take()!
let before = listener.executor.arrivals.withLock { $0.count }

// Resume, with this thread marked as "inside resume" for the duration of the call.
listener.executor.resuming.store(thread(), ordering: .sequentiallyConsistent)
let resumer = thread()
waiter.resume(returning: 1)
let duringResume = listener.executor.arrivals.withLock { $0.count } - before
listener.executor.resuming.store(0, ordering: .sequentiallyConsistent)

// The barrier: a job enqueued on the listener's actor right after the resume.
let seenAtBarrier = await listener.barrier()
await listening.value
let arrivals = listener.executor.arrivals.withLock { Array($0[before...]) }
done.store(true, ordering: .sequentiallyConsistent)
runner.join()

print("resume was called on thread \(resumer)")
print("jobs that reached the listener's executor inside the call to resume: \(duringResume)")
for (index, arrival) in arrivals.enumerated() {
    print("job \(index + 1) after the resume: enqueued from thread \(arrival.from)\(arrival.from == resumer ? " (the resumer's)" : " (not the resumer's)")")
}
print("what the barrier saw: \(seenAtBarrier) (1 = the listener's body ran first)")

/// A plain thread.
final class Thread2 {
    var handle = pthread_t()
    init(_ body: @escaping @Sendable () -> Void) {
        let box = Unmanaged.passRetained(Box(body))
        pthread_create(&handle, nil, { raw in
            let box = Unmanaged<Box>.fromOpaque(raw!).takeRetainedValue()
            box.body()
            return nil
        }, box.toOpaque())
    }
    func join() { pthread_join(handle, nil) }
    final class Box { let body: @Sendable () -> Void; init(_ body: @escaping @Sendable () -> Void) { self.body = body } }
}
