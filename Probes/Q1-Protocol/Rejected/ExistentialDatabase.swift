// A call on `any Database` directly, where the body's parameter is a `~Copyable` associated type. Swift 6.4.2 stops
// with "copy of noncopyable typed value. This is a compiler bug". Nothing of ISO 9075 is needed to see it, and
// `~Escapable` alone does not cause it. Passing the existential to a generic function, which opens it, is accepted:
// see `throughAnExistential` in Sources/Call Site/main.swift.
protocol Database {
    associatedtype Connection: ~Copyable
    func write<Value>(_ body: (borrowing Connection) -> Value) -> Value
}

func existential(_ database: any Database) {
    let _: Int = database.write { _ in 1 }
}
