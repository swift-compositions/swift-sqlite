#if CloudKit
    #if canImport(CloudKit)
        import Foundation
        public import SQL
        import SQL_Macros
        public import SQLite

        @Table
        package struct ForeignKey {
            let table: String
            let from: String
            let to: String
            let onUpdate: SQLite.Pragma.ForeignKey.Action
            let onDelete: SQLite.Pragma.ForeignKey.Action
            let isNotNull: Bool
        }
    #endif

#endif
