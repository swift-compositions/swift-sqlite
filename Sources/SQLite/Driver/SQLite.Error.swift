public import SQLite_SQL
internal import GRDBSQLite
public import ISO_9075_Call_Level_Interface

extension SQLite {
    /// An error SQLite reported: its result code, its message, and the statement that gave it.
    ///
    /// Opening, closing and backing up a ``SQLite/Database`` throw this. A read, a write or a statement throws the
    /// call-level interface's error, a diagnostic that carries this error's ``extendedCode`` as its native code:
    /// ``SQLite/Error/Code/init(_:)-(ISO_9075.Error)`` reads it back.
    public struct Error: Swift.Error, Hashable, Sendable, CustomStringConvertible {
        /// The primary result code: the least significant 8 bits of ``extendedCode``.
        public var code: Code { Code(primary: extendedCode) }

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
    /// A failure the call-level interface reported, in SQLite's terms: a value that could not be decoded or bound
    /// is a datatype mismatch (`SQLITE_MISMATCH`); any other is an error (`SQLITE_ERROR`), described in ``message``.
    package init(_ error: ISO.`9075`.Error) {
        switch error {
        case .decoding, .binding: self.init(extendedCode: .mismatch, message: "\(error)")
        case .connection, .execution, .transaction: self.init(extendedCode: .error, message: "\(error)")
        case .diagnostic(let diagnostic):
            self.init(extendedCode: Code(diagnostic) ?? .error, message: diagnostic.message)
        }
    }
}

extension ISO.`9075`.Error {
    /// An ``SQLite/Error`` as the call-level interface's error, for a contract that names no database: a diagnostic
    /// whose state is the result code's condition in ISO 9075 terms, whose native code is the extended result code,
    /// and whose message is SQLite's.
    public init(_ error: SQLite.Error) {
        self = .diagnostic(
            ISO.`9075`.Diagnostic(
                state: ISO.`9075`.Diagnostic.State(error.code),
                native: error.extendedCode.rawValue,
                message: error.message ?? error.description
            )
        )
    }
}

extension ISO.`9075`.Diagnostic.State {
    /// The ISO 9075 condition an SQLite result code reports.
    public init(_ code: SQLite.Error.Code) {
        self =
            switch code {
            case .constraint: .integrityConstraintViolation
            case .error: .syntaxErrorOrAccessRuleViolation
            case .mismatch: .dataException
            case .tooBig: .stringDataRightTruncation
            case .readonly: .readOnlyTransaction
            case .busy, .locked: .serializationFailure
            case .interrupt: .operationCanceled
            case .cannotOpen, .notADatabase: .unableToEstablishConnection
            default: .generalError
            }
    }
}

extension SQLite.Error.Code {
    /// The extended result code SQLite reported for `diagnostic`: its native code. `nil` for a diagnostic that carries
    /// none, which SQLite did not report.
    public init?(_ diagnostic: ISO.`9075`.Diagnostic) {
        guard let code = diagnostic.native else { return nil }
        self.init(rawValue: code)
    }

    /// The extended result code SQLite reported for `error`, when it is a diagnostic SQLite reported.
    public init?(_ error: ISO.`9075`.Error) {
        guard case .diagnostic(let diagnostic) = error else { return nil }
        self.init(diagnostic)
    }

    /// The primary result code of `code`: its least significant 8 bits.
    public init(primary code: Self) {
        self.init(rawValue: code.rawValue & 0xFF)
    }
}

extension SQLite.Error {
    /// What SQLite last reported on `connection`, for `statement`.
    @unsafe
    init(connection: OpaquePointer, statement: String? = nil) {
        self.init(
            extendedCode: Code(rawValue: unsafe sqlite3_extended_errcode(connection)),
            message: unsafe String(cString: sqlite3_errmsg(connection)),
            statement: statement
        )
    }

    /// A result code with SQLite's own description of it, for a failure no connection holds a message for.
    init(code: Int32, statement: String? = nil) {
        self.init(
            extendedCode: Code(rawValue: code),
            message: unsafe String(cString: sqlite3_errstr(code)),
            statement: statement
        )
    }

    /// What every use of a closed database throws.
    static var closed: SQLite.Error { SQLite.Error(extendedCode: .misuse, message: "Connection is closed") }

    /// What a cancelled task's read or write throws: SQLite's interrupt.
    static var cancelled: SQLite.Error { SQLite.Error(extendedCode: .interrupt, message: "cancelled") }
}
