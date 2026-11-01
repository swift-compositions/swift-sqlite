#if Dependencies
    public import Dependencies

    extension SQLite.Database {
        /// The key of ``Dependency/Values/defaultDatabase``: until a database is wired, each graph gets a fresh, empty
        /// database in memory, so nothing it writes outlives it.
        fileprivate enum Key: Dependency.Key {}
    }

    extension SQLite.Database.Key {
        static var liveValue: SQLite.Database { .unconfigured }
        static var testValue: SQLite.Database { .unconfigured }
    }

    extension SQLite.Database {
        fileprivate static var unconfigured: SQLite.Database {
            do throws(SQLite.Error) {
                return try SQLite.Database()
            } catch {
                preconditionFailure("an empty database in memory could not be opened: \(error)")
            }
        }
    }

    extension Dependency.Values {
        /// The ambient database. Wire the application's at launch with
        /// `withDependencies { $0.defaultDatabase = try SQLite.Database(path: …) }`; until then it is an empty database in
        /// memory.
        // swift-linter:disable:next compound identifier
        // REASON: defaultDatabase is the name every SQLite consumer and the examples already read through @Dependency.
        public var defaultDatabase: SQLite.Database {
            get { self[SQLite.Database.Key.self] }
            set { self[SQLite.Database.Key.self] = newValue }
        }
    }
#endif
