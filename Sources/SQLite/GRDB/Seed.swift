#if GRDB
    package import GRDB
    public import SQL

    extension SQLite.Connection {
        public func seed(@SeedsBuilder _ build: () -> [Seed]) throws {
            try translatingErrors { try database.seed(build) }
        }
    }

    extension GRDB.Database {
        package func seed(@SeedsBuilder _ build: () -> [Seed]) throws {
            for insert in Seeds(build) {
                try insert.execute(self)
            }
        }
    }
#endif
