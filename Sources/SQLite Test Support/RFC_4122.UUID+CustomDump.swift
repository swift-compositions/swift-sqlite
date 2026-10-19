#if GRDB
    public import CustomDump
    public import RFC_4122

    extension RFC_4122.UUID: @retroactive CustomDumpStringConvertible {
        public var customDumpDescription: String {
            "RFC_4122.UUID(\(description))"
        }
    }

#endif
