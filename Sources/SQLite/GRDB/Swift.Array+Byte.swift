#if GRDB
    package import Byte

    extension Swift.Array where Element == Byte {
        /// A copy of the bytes in `raw`, made in one pass.
        ///
        /// `Byte` is a `@frozen` struct whose only stored property is a `UInt8`, so an
        /// array of bytes is laid out exactly like the raw memory it is copied from.
        /// A per-element `Byte(bitPattern:)` map costs a call per byte, which on a
        /// multi-megabyte blob dominated every read.
        @unsafe
        package init(copying raw: UnsafeRawBufferPointer) {
            self = unsafe Swift.Array(unsafeUninitializedCapacity: raw.count) { buffer, count in
                unsafe UnsafeMutableRawBufferPointer(buffer).copyMemory(from: raw)
                count = raw.count
            }
        }
    }
#endif
