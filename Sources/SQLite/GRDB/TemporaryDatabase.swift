#if GRDB
    import File_System_Core
    import GRDB
    public import RFC_4122

    func temporaryDatabasePool(
        configuration: Configuration = Configuration(),
        uuid: @escaping @Sendable () -> RFC_4122.UUID = systemRandomUUID
    ) throws -> DatabasePool {
        let directory = try File.Path.Temporary.deterministic(
            prefix: "",
            key: "org.swift-institute.SQLite",
            suffix: ""
        )
        try File.System.Create.Directory.create(at: directory, createIntermediates: true)
        return try DatabasePool(
            path: Swift.String(directory / File.Path.Component("\(Swift.String(uuid())).db")),
            configuration: configuration
        )
    }

    @usableFromInline
    package func systemRandomUUID() -> RFC_4122.UUID {
        RFC_4122.UUID.v4 { buffer in
            var generator = SystemRandomNumberGenerator()
            for index in buffer.indices {
                unsafe buffer[index] = generator.next()
            }
        }
    }

#endif
