#if GRDB
    public import GRDB
    public import SQL

    extension GRDB.Database {
        public func seed(@SeedsBuilder _ build: () -> [Seed]) throws {
            for insert in Seeds(build) {
                try insert.execute(self)
            }
        }
    }
#endif
