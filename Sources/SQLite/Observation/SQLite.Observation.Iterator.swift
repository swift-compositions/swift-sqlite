#if Observation
    public import ISO_9075_Call_Level_Interface

    extension SQLite.Observation {
        public struct Iterator: AsyncIteratorProtocol {
            var values: AsyncThrowingStream<Value, any Swift.Error>.Iterator
            let lifetime: Lifetime

            init(_ values: AsyncThrowingStream<Value, any Swift.Error>.Iterator, lifetime: Lifetime) {
                self.values = values
                self.lifetime = lifetime
            }
        }
    }

    extension SQLite.Observation.Iterator {
        public mutating func next() async throws(ISO_9075.Error) -> Value? {
            try await next(isolation: #isolation)
        }

        public mutating func next(isolation actor: isolated (any Actor)?) async throws(ISO_9075.Error) -> Value? {
            do {
                return try await values.next(isolation: actor)
            } catch let error as ISO_9075.Error {
                throw error
            } catch {
                throw .execution("\(error)")
            }
        }
    }
#endif
