public import SQLite_SQL
#if GRDB
    package import GRDB

    extension SQLite {
        /// How a ``SQLite/Database`` opens its connections.
        public struct Configuration: Sendable {
            /// Opens every connection read-only: a write throws ``SQLite/Error`` with code ``SQLite/Error/Code/readonly``.
            public var readonly = false

            /// Enforces foreign keys on every connection (`PRAGMA foreign_keys = ON`). On by default.
            public var foreignKeysEnabled = true

            /// How long a connection waits on a database another connection has locked before it throws
            /// ``SQLite/Error/Code/busy``. `nil`, the default, throws at once.
            public var busyTimeout: Duration?

            /// A name for the database, shown in its connections' dispatch queue labels.
            public var label: String?

            /// The most connections a ``SQLite/Database/Kind/pool`` reads with at once. Five by default.
            public var maximumReaderCount = 5

            private var preparations: [@Sendable (SQLite.Connection) throws -> Void] = []

            public init() {}

            /// Runs `body` on each connection as it opens, before any other statement: to add functions and collations,
            /// attach databases, or start a trace.
            public mutating func prepareDatabase(_ body: @escaping @Sendable (SQLite.Connection) throws -> Void) {
                preparations.append(body)
            }
        }
    }

    extension SQLite.Configuration {
        /// The driver's configuration for a read-only database with no `-shm` file. SQLite can't open such a WAL
        /// database on a read-only connection, which may not create that file. So it opens read and write and refuses
        /// writes by `PRAGMA query_only`, before any other statement. A write throws ``SQLite/Error/Code/readonly``,
        /// as a read-only connection's does.
        package var restored: GRDB.Configuration {
            var configuration = driver
            configuration.readonly = false
            configuration.prepareDatabase { database in
                try database.execute(sql: "PRAGMA query_only = ON")
            }
            return configuration
        }

        /// The driver's configuration.
        package var driver: GRDB.Configuration {
            var configuration = GRDB.Configuration()
            configuration.readonly = readonly
            configuration.foreignKeysEnabled = foreignKeysEnabled
            if let busyTimeout {
                let (seconds, attoseconds) = busyTimeout.components
                configuration.busyMode = .timeout(Double(seconds) + Double(attoseconds) / 1e18)
            }
            configuration.label = label
            configuration.maximumReaderCount = maximumReaderCount
            for preparation in preparations {
                configuration.prepareDatabase { database in
                    try translatingErrors { try preparation(SQLite.Connection(database)) }
                }
            }
            return configuration
        }
    }
#endif
