public import SQLite_SQL
#if GRDB
    public import RFC_4122

    @usableFromInline
    package func systemRandomUUID() -> RFC_4122.UUID {
        unsafe RFC_4122.UUID.v4 { buffer in
            var generator = SystemRandomNumberGenerator()
            for index in buffer.indices {
                unsafe buffer[index] = generator.next()
            }
        }
    }

#endif
