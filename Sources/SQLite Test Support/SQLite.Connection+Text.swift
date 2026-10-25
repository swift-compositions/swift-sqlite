#if GRDB
    public import ISO_9075_Foundation
    public import SQL
    public import SQLite

    // Tests that probe a store's triggers, migrations and schema state the SQL they test as text. These are the entry
    // points for that text, in tests only: production code builds statements with swift-sql.

    extension SQLite.Connection {
        /// Runs `sql`, binding each `?` outside quotes to the next of `arguments`.
        public func execute(sql: String, arguments: [any QueryBindable] = []) throws {
            try SQLQueryExpression(ISO_9075.Fragment(text: sql, arguments: arguments)).execute(self)
        }
    }

    extension QueryRepresentable {
        /// The first column of each row `sql` returns, as `Self`.
        public static func fetchAll(
            _ connection: SQLite.Connection,
            sql: String,
            arguments: [any QueryBindable] = []
        ) throws -> [QueryOutput] {
            try SQLQueryExpression<Self>(ISO_9075.Fragment(text: sql, arguments: arguments)).fetchAll(connection)
        }

        /// The first column of the first row `sql` returns, as `Self`, or none when it returns no row.
        public static func fetchOne(
            _ connection: SQLite.Connection,
            sql: String,
            arguments: [any QueryBindable] = []
        ) throws -> QueryOutput? {
            try SQLQueryExpression<Self>(ISO_9075.Fragment(text: sql, arguments: arguments)).fetchOne(connection)
        }
    }

    extension SQLite.Row {
        /// Every row `sql` returns, each column by name.
        public static func fetchAll(
            _ connection: SQLite.Connection,
            sql: String,
            arguments: [any QueryBindable] = []
        ) throws -> [SQLite.Row] {
            try connection.fetchAll(SQLite().render(ISO_9075.Fragment(text: sql, arguments: arguments))) { $0 }
        }

        /// The first row `sql` returns, or none.
        public static func fetchOne(
            _ connection: SQLite.Connection,
            sql: String,
            arguments: [any QueryBindable] = []
        ) throws -> SQLite.Row? {
            try fetchAll(connection, sql: sql, arguments: arguments).first
        }

        /// The row's column names, in order.
        public var columnNames: [String] { columns }

        /// The row's values, in column order.
        public var databaseValues: [ISO_9075.Value] {
            columns.indices.map { (try? value(at: $0)) ?? .null }
        }

        /// The value of the column named `name`, or `.null` when the row has none by that name.
        public subscript(_ name: String) -> ISO_9075.Value {
            columns.firstIndex(of: name).flatMap { try? value(at: $0) } ?? .null
        }

        /// The value of the column named `name`, as `Value`.
        public subscript<Value: QueryRepresentable>(_ name: String) -> Value.QueryOutput {
            get throws {
                var decoder = SQLite.Row.Decoder(value: self[name])
                return try Value(decoder: &decoder).queryOutput
            }
        }
    }

    extension SQLite.Row: CustomStringConvertible {
        /// The row as `[name:value …]`, each value as SQLite would quote it.
        public var description: String {
            "[" + zip(columns, databaseValues).map { "\($0):\(SQLite.Row.quoted($1))" }.joined(separator: " ") + "]"
        }

        package static func quoted(_ value: ISO_9075.Value) -> String {
            switch value {
            case .null: "NULL"
            case .bool(let flag): flag ? "1" : "0"
            case .int(let number): String(number)
            case .double(let number): String(number)
            case .text(let text): "'" + text.replacing("'", with: "''") + "'"
            case .blob(let bytes), .json(let bytes): "x'" + bytes.map { String($0.rawValue, radix: 16).leftPadding(2) }.joined() + "'"
            default: "\(value)"
            }
        }
    }

    extension ISO_9075.Fragment {
        /// `sql` with each `?` outside a quoted literal or identifier bound to the next of `arguments`.
        package init(text sql: String, arguments: [any QueryBindable]) {
            var segments: [Segment] = []
            var buffer = ""
            var quote: Character?
            var remaining = arguments[...]
            for character in sql {
                if let open = quote {
                    if character == open { quote = nil }
                    buffer.append(character)
                } else if character == "'" || character == "\"" {
                    quote = character
                    buffer.append(character)
                } else if character == "?", let argument = remaining.popFirst() {
                    if !buffer.isEmpty { segments.append(.sql(buffer)); buffer = "" }
                    segments.append(.value(argument.queryBinding))
                } else {
                    buffer.append(character)
                }
            }
            if !buffer.isEmpty { segments.append(.sql(buffer)) }
            self.init(segments: segments)
        }
    }

    extension String {
        fileprivate func leftPadding(_ width: Int) -> String {
            String(repeating: "0", count: Swift.max(0, width - count)) + self
        }
    }
#endif
