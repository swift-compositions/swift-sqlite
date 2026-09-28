#if CloudKit
#if canImport(CloudKit)
  import Foundation
  public import SQL
  import SQL_Macros

  @Table
  package struct ForeignKey {
    let table: String
    let from: String
    let to: String
    let onUpdate: ForeignKeyAction
    let onDelete: ForeignKeyAction
    let isNotNull: Bool
  }
#endif

#endif
