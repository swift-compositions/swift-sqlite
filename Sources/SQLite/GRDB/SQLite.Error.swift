public import SQLite_SQL
#if GRDB
    package import GRDB
    public import ISO_9075_Call_Level_Interface

    extension SQLite {
        /// An error SQLite reported: its result code, its message, and the statement that gave it.
        ///
        /// Every operation of ``SQLite/Database`` and ``SQLite/Connection`` throws this for a failure SQLite reports,
        /// so a caller tells a constraint violation from a busy database by ``code``, not by the driver's own error type.
        public struct Error: Swift.Error, Hashable, Sendable, CustomStringConvertible {
            /// The primary result code: the least significant 8 bits of ``extendedCode``.
            public var code: Code { Code(rawValue: extendedCode.rawValue & 0xFF) }

            /// The extended result code, such as `SQLITE_CONSTRAINT_FOREIGNKEY`.
            public let extendedCode: Code

            /// SQLite's message, when it gave one.
            public let message: String?

            /// The statement that gave the error, when there was one.
            public let statement: String?

            public init(extendedCode: Code, message: String? = nil, statement: String? = nil) {
                self.extendedCode = extendedCode
                self.message = message
                self.statement = statement
            }

            public var description: String {
                var description = "SQLite error \(extendedCode.rawValue)"
                if let message { description += ": \(message)" }
                if let statement { description += " - while executing `\(statement)`" }
                return description
            }
        }
    }

    extension SQLite.Error {
        /// An SQLite result code (<https://www.sqlite.org/rescode.html>).
        public struct Code: RawRepresentable, Hashable, Sendable {
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
        }
    }

    extension SQLite.Error.Code {
        public static let error = Self(rawValue: 1)
        public static let `internal` = Self(rawValue: 2)
        public static let permission = Self(rawValue: 3)
        public static let abort = Self(rawValue: 4)
        public static let busy = Self(rawValue: 5)
        public static let locked = Self(rawValue: 6)
        public static let noMemory = Self(rawValue: 7)
        public static let readonly = Self(rawValue: 8)
        public static let interrupt = Self(rawValue: 9)
        public static let input = Self(rawValue: 10)
        public static let corrupt = Self(rawValue: 11)
        public static let notFound = Self(rawValue: 12)
        public static let full = Self(rawValue: 13)
        public static let cannotOpen = Self(rawValue: 14)
        public static let `protocol` = Self(rawValue: 15)
        public static let schema = Self(rawValue: 17)
        public static let tooBig = Self(rawValue: 18)
        public static let constraint = Self(rawValue: 19)
        public static let mismatch = Self(rawValue: 20)
        public static let misuse = Self(rawValue: 21)
        public static let authorization = Self(rawValue: 23)
        public static let range = Self(rawValue: 25)
        public static let notADatabase = Self(rawValue: 26)
        public static let foreignKeyConstraint = Self(rawValue: 787)
        public static let uniqueConstraint = Self(rawValue: 2067)
        public static let primaryKeyConstraint = Self(rawValue: 1555)
        public static let notNullConstraint = Self(rawValue: 1299)
        public static let checkConstraint = Self(rawValue: 275)
    }

    extension SQLite.Error {
        package init(_ error: GRDB.DatabaseError) {
            self.init(
                extendedCode: Code(rawValue: error.extendedResultCode.rawValue),
                message: error.message,
                statement: error.sql
            )
        }

        /// The driver's error as an ``SQLite/Error``; any other error unchanged.
        package static func translated(_ error: any Swift.Error) -> any Swift.Error {
            (error as? GRDB.DatabaseError).map(SQLite.Error.init) ?? error
        }
    }

    /// Runs `body`, throwing the driver's errors as ``SQLite/Error``.
    package func translatingErrors<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch {
            throw SQLite.Error.translated(error)
        }
    }

    /// Runs `body`, throwing the driver's errors as ``SQLite/Error``.
    package func translatingErrors<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch {
            throw SQLite.Error.translated(error)
        }
    }

    extension SQLite.Error {
        /// A failure the call-level interface reported, in SQLite's terms: a value that could not be decoded or bound
        /// is a datatype mismatch (`SQLITE_MISMATCH`); any other is an error (`SQLITE_ERROR`), described in ``message``.
        package init(_ error: ISO_9075.Error) {
            switch error {
            case .decoding, .binding: self.init(extendedCode: .mismatch, message: "\(error)")
            case .connection, .execution, .transaction: self.init(extendedCode: .error, message: "\(error)")
            }
        }

        /// Any error a read, a write or a statement can meet, as an ``SQLite/Error``: the driver's by its result code,
        /// the call-level interface's by ``init(_:)-(ISO_9075.Error)``, and a cancelled task as an interrupt.
        package static func typed(_ error: any Swift.Error) -> SQLite.Error {
            switch error {
            case let error as SQLite.Error: error
            case let error as GRDB.DatabaseError: SQLite.Error(error)
            case let error as ISO_9075.Error: SQLite.Error(error)
            case is CancellationError: SQLite.Error(extendedCode: .interrupt, message: "cancelled")
            default: SQLite.Error(extendedCode: .error, message: "\(error)")
            }
        }
    }

    extension ISO_9075.Error {
        /// An ``SQLite/Error`` as the call-level interface's error, for a contract that names no database: an execution
        /// error described by its result code, message and statement.
        public init(_ error: SQLite.Error) {
            self = .execution(error.description)
        }
    }

    /// Runs `body`, throwing what fails as ``SQLite/Error``.
    package func executing<T>(_ body: () throws -> T) throws(SQLite.Error) -> T {
        do {
            return try body()
        } catch {
            throw SQLite.Error.typed(error)
        }
    }

    /// Runs `body`, throwing what fails as ``SQLite/Error``.
    package func executing<T>(_ body: () async throws -> T) async throws(SQLite.Error) -> T {
        do {
            return try await body()
        } catch {
            throw SQLite.Error.typed(error)
        }
    }
#endif
