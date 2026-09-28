#if CloudKit
#if canImport(CloudKit)
  package import SQL
  import SQL_Macros

  @Table
  package struct TableInfo: Codable, Hashable {
    let defaultValue: String?
    let isPrimaryKey: Bool
    package let name: String
    let isNotNull: Bool
    let type: String
  }
#endif

#endif
