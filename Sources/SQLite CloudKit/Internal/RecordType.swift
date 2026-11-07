#if CloudKit
    #if canImport(CloudKit)
        package import SQLite
        package import SQL
        import SQL_Macros

        @Table("swiftsqlite_icloud_recordTypes")
        package struct RecordType: Hashable {
            @Column(primaryKey: true)
            package let tableName: String
            package let schema: String
            @Column(as: JSONRepresentation<Set<TableInfo>>.self)
            package let tableInfo: Set<TableInfo>

            package static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.tableName == rhs.tableName && lhs.schema == rhs.schema && lhs.tableInfo == rhs.tableInfo
            }

            package func hash(into hasher: inout Hasher) {
                hasher.combine(tableName)
                hasher.combine(schema)
                hasher.combine(tableInfo)
            }
        }
    #endif

#endif
