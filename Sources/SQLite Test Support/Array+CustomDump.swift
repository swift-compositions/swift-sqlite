#if GRDB
    public import Byte
    public import CustomDump

    extension Array: @retroactive CustomDumpStringConvertible where Element == Byte {
        public var customDumpDescription: String {
            "[Byte](\(count) bytes)"
        }
    }

#endif
