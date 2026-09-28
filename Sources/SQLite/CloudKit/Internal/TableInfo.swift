#if CloudKit
#if canImport(CloudKit)
  package import SQL

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
