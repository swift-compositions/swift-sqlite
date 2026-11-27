public import ISO_9075_Call_Level_Interface
public import SQL
import SQL_Test_Support
public import SQLite
public import Test

extension Test::Test.Snapshot.Strategy where Format == Swift.String {
    /// The rows the statement returns when read from `database`, drawn as SQL Test Support's `.rows` draws them,
    /// with `drawing` first.
    @_disfavoredOverload
    public static func rows<each V: QueryRepresentable>(
        in database: SQLite.Database,
        drawing: @escaping (Any) -> Swift.String? = { _ in nil }
    ) -> Self
    where Value: SQL::Statement<(repeat each V)> {
        .rows(
            { (statement: Value) throws(ISO.`9075`.Error) in
                let query = statement.query
                return try database.read { (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                    Carried(try SQLQueryExpression(query, as: (repeat each V).self).fetch.all(connection))
                }.rows
            },
            drawing: drawing
        )
    }

    /// The rows the statement returns when read on the writer's connection of `database`, which sees what is attached
    /// to that connection alone. The statement must only read.
    @_disfavoredOverload
    public static func rows<each V: QueryRepresentable>(
        writing database: SQLite.Database,
        drawing: @escaping (Any) -> Swift.String? = { _ in nil }
    ) -> Self
    where Value: SQL::Statement<(repeat each V)> {
        .rows(
            { (statement: Value) throws(ISO.`9075`.Error) in
                let query = statement.query
                do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
                    return try database.readOnWriter {
                        (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                        Carried(try SQLQueryExpression(query, as: (repeat each V).self).fetch.all(connection))
                    }.rows
                } catch {
                    throw error.error
                }
            },
            drawing: drawing
        )
    }

    /// Every column of the selected tables, read from `database`.
    public static func rows<each J: SQL::Table>(
        in database: SQLite.Database,
        drawing: @escaping (Any) -> Swift.String? = { _ in nil }
    ) -> Self
    where Value: SelectStatement, Value.QueryValue == (), Value.Joins == (repeat each J) {
        .rows(
            { (statement: Value) throws(ISO.`9075`.Error) in
                let query = statement.selectStar().query
                return try database.read { (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                    Carried(try SQLQueryExpression(query, as: (Value.From, repeat each J).self).fetch.all(connection))
                }.rows
            },
            drawing: drawing
        )
    }

    /// Every column of the selected tables, read on the writer's connection of `database`.
    public static func rows<each J: SQL::Table>(
        writing database: SQLite.Database,
        drawing: @escaping (Any) -> Swift.String? = { _ in nil }
    ) -> Self
    where Value: SelectStatement, Value.QueryValue == (), Value.Joins == (repeat each J) {
        .rows(
            { (statement: Value) throws(ISO.`9075`.Error) in
                let query = statement.selectStar().query
                do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
                    return try database.readOnWriter {
                        (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                        Carried(try SQLQueryExpression(query, as: (Value.From, repeat each J).self).fetch.all(connection))
                    }.rows
                } catch {
                    throw error.error
                }
            },
            drawing: drawing
        )
    }
}

/// Rows on their way out of a read's body.
///
/// The compiler does not see that an array of a pack of values, decoded in the body, is made there and shares nothing
/// with the connection. It is: each row is decoded from the statement into new values, and the caller is the only one
/// that reads them.
private struct Carried<Row>: @unchecked Sendable {
    let rows: [Row]

    init(_ rows: [Row]) {
        self.rows = rows
    }
}
