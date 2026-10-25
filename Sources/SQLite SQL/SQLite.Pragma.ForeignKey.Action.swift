public import SQL

extension SQLite.Pragma.ForeignKey {
    /// An action SQLite performs when a referenced row is updated or deleted.
    public enum Action: String, QueryBindable, Sendable {
        case cascade = "CASCADE"
        case restrict = "RESTRICT"
        case setDefault = "SET DEFAULT"
        case setNull = "SET NULL"
        case noAction = "NO ACTION"
    }
}
