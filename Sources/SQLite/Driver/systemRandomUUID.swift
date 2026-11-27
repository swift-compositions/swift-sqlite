public import RFC_4122

@usableFromInline
package func systemRandomUUID() -> IETF.RFC.`4122`.UUID {
    unsafe IETF.RFC.`4122`.UUID.v4 { buffer in
        var generator = SystemRandomNumberGenerator()
        for index in buffer.indices {
            unsafe buffer[index] = generator.next()
        }
    }
}
