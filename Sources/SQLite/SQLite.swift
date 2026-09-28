public import ISO_9075_Foundation

public struct SQLite: ISO_9075.Dialect {
    public init() {}

    public func placeholder(_ offset: Int) -> String { "?" }

    public var defaultPrimaryKey: String { "NULL" }

    public var jsonBooleanOpen: String { "json(CASE " }

    public var jsonBooleanClose: String { " WHEN 0 THEN 'false' WHEN 1 THEN 'true' END)" }
}
