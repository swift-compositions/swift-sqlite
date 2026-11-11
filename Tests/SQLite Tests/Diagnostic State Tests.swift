#if GRDB
    import ISO_9075_Call_Level_Interface
    import SQLite
    import Testing

    extension ISO_9075.Diagnostic.State {
        @Suite struct Test {
            @Suite struct Unit {}
        }
    }

    extension SQLite.Error.Code {
        @Suite struct Test {
            @Suite struct Unit {}
        }
    }

    extension ISO_9075.Diagnostic.State.Test.Unit {
        @Test func `a constraint violation is an integrity constraint violation`() {
            #expect(ISO_9075.Diagnostic.State(.constraint) == .integrityConstraintViolation)
        }

        @Test func `an SQL error is a syntax error or access rule violation`() {
            #expect(ISO_9075.Diagnostic.State(.error) == .syntaxErrorOrAccessRuleViolation)
        }

        @Test func `a datatype mismatch is a data exception`() {
            #expect(ISO_9075.Diagnostic.State(.mismatch) == .dataException)
        }

        @Test func `a value too big is string data right truncation`() {
            #expect(ISO_9075.Diagnostic.State(.tooBig) == .stringDataRightTruncation)
        }

        @Test func `a read-only database is a read-only transaction`() {
            #expect(ISO_9075.Diagnostic.State(.readonly) == .readOnlyTransaction)
        }

        @Test func `a busy database is a serialization failure`() {
            #expect(ISO_9075.Diagnostic.State(.busy) == .serializationFailure)
        }

        @Test func `a locked table is a serialization failure`() {
            #expect(ISO_9075.Diagnostic.State(.locked) == .serializationFailure)
        }

        @Test func `an interrupt is a cancelled operation`() {
            #expect(ISO_9075.Diagnostic.State(.interrupt) == .operationCanceled)
        }

        @Test func `a database that cannot be opened is a connection that cannot be established`() {
            #expect(ISO_9075.Diagnostic.State(.cannotOpen) == .unableToEstablishConnection)
        }

        @Test func `a file that is not a database is a connection that cannot be established`() {
            #expect(ISO_9075.Diagnostic.State(.notADatabase) == .unableToEstablishConnection)
        }

        @Test func `any other result code is a general error`() {
            #expect(ISO_9075.Diagnostic.State(.full) == .generalError)
        }

        @Test func `an extended code takes its primary code's state`() {
            #expect(ISO_9075.Diagnostic.State(SQLite.Error(extendedCode: .primaryKeyConstraint).code) == .integrityConstraintViolation)
        }
    }

    extension SQLite.Error.Code.Test.Unit {
        @Test func `a diagnostic SQLite reported gives back its extended and primary code`() {
            let error = ISO_9075.Error(SQLite.Error(extendedCode: .uniqueConstraint, message: "UNIQUE constraint failed"))
            #expect(SQLite.Error.Code(error) == .uniqueConstraint)
            #expect(SQLite.Error.Code(error).map(SQLite.Error.Code.init(primary:)) == .constraint)
        }

        @Test func `a diagnostic another engine reported has no SQLite code`() {
            let error = ISO_9075.Error.diagnostic(ISO_9075.Diagnostic(state: .integrityConstraintViolation, message: "duplicate key"))
            #expect(SQLite.Error.Code(error) == nil)
        }

        @Test func `an error that is no diagnostic has no SQLite code`() {
            #expect(SQLite.Error.Code(ISO_9075.Error.execution("no diagnostic")) == nil)
        }

        @Test func `a missing table is SQLITE_ERROR, read as the result code`() async throws {
            let database = try SQLite.Database()
            let error = await #expect(throws: ISO_9075.Error.self) {
                try await database.read { connection throws(ISO_9075.Error) in
                    _ = try connection.execute(#"SELECT * FROM "missing""# as ISO_9075.Fragment)
                }
            }
            #expect(error.flatMap(SQLite.Error.Code.init).map(SQLite.Error.Code.init(primary:)) == .error)
            #expect(error?.state == .syntaxErrorOrAccessRuleViolation)
        }
    }
#endif
