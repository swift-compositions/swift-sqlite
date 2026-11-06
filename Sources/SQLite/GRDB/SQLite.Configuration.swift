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
        /// The driver's configuration for the connection that holds a read-only database's `-shm` file. SQLite can't
        /// open a WAL database with no such file on a read-only connection, which may not create it. So this one opens
        /// read and write, creates the file, and runs nothing else; the connections that read are truly read-only.
        /// `PRAGMA query_only` won't do in its place: GRDB turns it off at the end of every read.
        package var holder: GRDB.Configuration {
            var configuration = GRDB.Configuration()
            configuration.busyMode = driver.busyMode
            configuration.label = label
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
