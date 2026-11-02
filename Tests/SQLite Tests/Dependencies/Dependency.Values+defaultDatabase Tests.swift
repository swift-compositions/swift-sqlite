#if Dependencies
    import Dependencies
    import Foundation
    import SQLite
    import Testing

    @Suite(.timeLimit(.minutes(2)))
    struct `defaultDatabase Tests` {
        @Test
        func `an unwired graph gets an empty database in memory`() {
            @Dependency(\.defaultDatabase) var database
            #expect(database.path == ":memory:")
        }

        @Test
        func `a wired database is the one read back`() throws {
            let path = NSTemporaryDirectory() + "defaultDatabase-\(UInt64.random(in: 0 ... .max)).sqlite"
            let wired = try SQLite.Database(path: path, kind: .queue)
            withDependencies {
                $0.defaultDatabase = wired
            } operation: {
                @Dependency(\.defaultDatabase) var database
                #expect(database.path == path)
            }
        }
    }
#endif
