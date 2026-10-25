public import ISO_9075_Foundation
public import SQL

extension SQLite {
    /// The rows a connection's statements changed: the last statement's (`changes()`) and every statement's since the
    /// connection opened (`total_changes()`).
    public enum Changes {}
}

extension SQLite.Changes {
    /// The rows the most recent INSERT, UPDATE or DELETE on this connection changed.
    public static var last: some Statement<Int> {
        SQLQueryExpression<Int>("SELECT changes()")
    }

    /// The rows every INSERT, UPDATE and DELETE on this connection changed since it opened.
    public static var total: some Statement<Int> {
        SQLQueryExpression<Int>("SELECT total_changes()")
    }
}
