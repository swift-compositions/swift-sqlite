extension SQLite {
    /// Tables, by name: the ones a statement reads, or the ones it writes. The database a table is in is not part of
    /// its name here, so two tables with one name in two attached databases count as one.
    struct Region: Sendable {
        var tables: Set<String> = []

        /// What has no table to name: a change to the schema, a pragma that sets a value, an attached database.
        var everything = false

        var isEmpty: Bool { !everything && tables.isEmpty }

        mutating func formUnion(_ other: Region) {
            everything = everything || other.everything
            if !other.tables.isEmpty { tables.formUnion(other.tables) }
        }

        func intersects(_ other: Region) -> Bool {
            if isEmpty || other.isEmpty { return false }
            return everything || other.everything || !tables.isDisjoint(with: other.tables)
        }
    }

    /// What statements read and what they write, as SQLite reports it while it compiles them: a table that a
    /// trigger or a foreign key action writes is in it, and a table that a statement could write is in it also when
    /// it changes no row.
    struct Footprint: Sendable {
        var reads = Region()
        var writes = Region()

        var isEmpty: Bool { reads.isEmpty && writes.isEmpty }

        mutating func formUnion(_ other: Footprint) {
            reads.formUnion(other.reads)
            writes.formUnion(other.writes)
        }
    }
}
