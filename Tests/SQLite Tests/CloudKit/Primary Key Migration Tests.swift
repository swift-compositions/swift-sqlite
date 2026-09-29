#if CloudKit
    import CloudKit
    import Foundation
    import GRDB
    import InlineSnapshotTesting
    import RFC_4122
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_Test_Support
    import Testing

    @Suite struct `Primary key migration` {
        @Table("parents") struct Parent: Identifiable {
            let id: RFC_4122.UUID
            var title = ""
        }
        @Table("children") struct Child {
            let id: RFC_4122.UUID
            var title = ""
            var parentID: Parent.ID
        }
        @Table("tags") struct Tag {
            let id: RFC_4122.UUID
            var title = ""
        }
        @Table("phoneNumbers") struct PhoneNumber {
            @Column(primaryKey: true)
            let number: String
        }
        @Table("users") struct User {
            @Column(primaryKey: true)
            let identifier: RFC_4122.UUID
            var name = ""
        }
        let database: DatabaseQueue
        let incrementingUUID = IncrementingUUID()

        init() throws {
            database = try DatabaseQueue()
            database.writeWithoutTransaction { db in
                db.add(function: $uuid)
                db.add(function: $customUUID)
            }
        }

        @DatabaseFunction
        func uuid() -> RFC_4122.UUID {
            incrementingUUID()
        }

        @DatabaseFunction
        func customUUID() -> RFC_4122.UUID {
            incrementingUUID()
        }

        @Test func `migrates integer primary keys, foreign keys and missing primary keys to UUIDs`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "parents" (
                      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                      "title" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "children" (
                      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                      "title" TEXT NOT NULL,
                      "parentID" INTEGER NOT NULL REFERENCES "parents"("id") ON DELETE CASCADE
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "tags" (
                      "title" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try seed(db)
            }

            try migrate()

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "children",                                                        │
                │   tableName: "children",                                                   │
                │   sql: """                                                                 │
                │   CREATE TABLE "children" (                                                │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL,                                                 │
                │     "parentID" TEXT NOT NULL REFERENCES "parents"("id") ON DELETE CASCADE  │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "parents",                                                         │
                │   tableName: "parents",                                                    │
                │   sql: """                                                                 │
                │   CREATE TABLE "parents" (                                                 │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL                                                  │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "tags",                                                            │
                │   tableName: "tags",                                                       │
                │   sql: """                                                                 │
                │   CREATE TABLE "tags" (                                                    │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL                                                  │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                └────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            assertQuery(Parent.all, database: database) {
                """
                ┌────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7), │
                │   title: "foo"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6), │
                │   title: "bar"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6), │
                │   title: "baz"                                             │
                │ )                                                          │
                └────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Child.all, database: database) {
                """
                ┌─────────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(d66c67a9-39cd-8786-75a9-1c47f5c0e47f),      │
                │   title: "foo",                                                 │
                │   parentID: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(98219b0b-627e-b12b-8e8f-08ed4a7959bf),      │
                │   title: "bar",                                                 │
                │   parentID: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(7eae27fe-b38d-3806-6aa4-6f953c251bea),      │
                │   title: "baz",                                                 │
                │   parentID: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6) │
                │ )                                                               │
                └─────────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Tag.all, database: database) {
                """
                ┌────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Tag(                  │
                │   id: RFC_4122.UUID(00000000-0000-0000-0000-000000000001), │
                │   title: "personal"                                        │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Tag(                  │
                │   id: RFC_4122.UUID(00000000-0000-0000-0000-000000000002), │
                │   title: "business"                                        │
                │ )                                                          │
                └────────────────────────────────────────────────────────────┘
                """
            }
        }

        @Test func `preserves the rowid`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "parents" (
                      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                      "title" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    INSERT INTO "parents" ("id", "title") VALUES (1, 'blob'), (1000, 'blob jr')
                    """
                )
                .execute(db)
            }

            try migrate(tables: Parent.self)

            assertQuery(Parent.select { ($0.rowid, $0) }, database: database) {
                """
                ┌──────┬────────────────────────────────────────────────────────────┐
                │ 1    │ SQLite_Tests.`Primary key migration`.Parent(               │
                │      │   id: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7), │
                │      │   title: "blob"                                            │
                │      │ )                                                          │
                ├──────┼────────────────────────────────────────────────────────────┤
                │ 1000 │ SQLite_Tests.`Primary key migration`.Parent(               │
                │      │   id: RFC_4122.UUID(ec5f9355-c981-e3c7-3246-09a01e0c4897), │
                │      │   title: "blob jr"                                         │
                │      │ )                                                          │
                └──────┴────────────────────────────────────────────────────────────┘
                """
            }
        }

        @Test func `rejects a primary key that is already a UUID`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "parents" (
                      "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                      "title" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
            }

            let error = #expect(throws: (any Error).self) {
                try migrate(tables: Parent.self)
            }
            assertInlineSnapshot(of: error?.localizedDescription, as: .customDump) {
                """
                "Invalid primary key. The table must have either no primary key or a single integer primary key to migrate."
                """
            }

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌──────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                            │
                │   type: .table,                                                          │
                │   name: "parents",                                                       │
                │   tableName: "parents",                                                  │
                │   sql: """                                                               │
                │   CREATE TABLE "parents" (                                               │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()), │
                │     "title" TEXT NOT NULL                                                │
                │   ) STRICT                                                               │
                │   """                                                                    │
                │ )                                                                        │
                └──────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Test func `drops unique constraints`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "users" (
                      "id" INTEGER,
                      "title" TEXT NOT NULL,

                      PRIMARY KEY("id"),
                      UNIQUE("title") ON CONFLICT REPLACE
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "tags" (
                      "title" TEXT NOT NULL UNIQUE,
                      "name" TEXT NOT NULL UNIQUE ON CONFLICT IGNORE
                    ) STRICT
                    """
                )
                .execute(db)
            }

            try database.writeWithoutTransaction { db in
                try #sql("PRAGMA foreign_keys = OFF").execute(db)
                try db.inTransaction {
                    try SyncEngine.migratePrimaryKeys(
                        db,
                        tables: User.self,
                        Tag.self,
                        dropUniqueConstraints: true,
                        uuid: $uuid
                    )
                    return .commit
                }
                try #sql("PRAGMA foreign_keys = ON").execute(db)
            }

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "tags",                                                            │
                │   tableName: "tags",                                                       │
                │   sql: """                                                                 │
                │   CREATE TABLE "tags" (                                                    │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL,                                                 │
                │     "name" TEXT NOT NULL                                                   │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "users",                                                           │
                │   tableName: "users",                                                      │
                │   sql: """                                                                 │
                │   CREATE TABLE "users" (                                                   │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL) STRICT                                          │
                │   """                                                                      │
                │ )                                                                          │
                └────────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Table("users") struct PrimaryKeyNamedUnique {
            @Column(primaryKey: true)
            let unique: RFC_4122.UUID
            var title = ""
        }
        @Test func `migrates a primary key named unique`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "users" (
                      "unique" INTEGER,
                      "title" TEXT NOT NULL,
                      PRIMARY KEY("unique")
                    ) STRICT
                    """
                )
                .execute(db)
            }

            try database.writeWithoutTransaction { db in
                try #sql("PRAGMA foreign_keys = OFF").execute(db)
                try db.inTransaction {
                    try SyncEngine.migratePrimaryKeys(
                        db,
                        tables: PrimaryKeyNamedUnique.self,
                        dropUniqueConstraints: true,
                        uuid: $uuid
                    )
                    return .commit
                }
                try #sql("PRAGMA foreign_keys = ON").execute(db)
            }

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                  │
                │   type: .table,                                                                │
                │   name: "users",                                                               │
                │   tableName: "users",                                                          │
                │   sql: """                                                                     │
                │   CREATE TABLE "users" (                                                       │
                │     "unique" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL) STRICT                                              │
                │   """                                                                          │
                │ )                                                                              │
                └────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Test func `preserves column constraints`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "parents" (
                      "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE CHECK("id" > 0),
                      "title" TEXT NOT NULL CHECK(length("title") > 0)
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "children" (
                      "id" INTEGER PRIMARY KEY, -- No autoincrement
                      "title" TEXT COLLATE NOCASE NOT NULL DEFAULT (''),
                      "parentID" INTEGER NOT NULL REFERENCES "parents"("id") ON DELETE CASCADE,
                      "exclaimedTitle" TEXT NOT NULL AS ("title" || '!') STORED
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "tags" (
                      "title" TEXT NOT NULL UNIQUE
                    ) STRICT
                    """
                )
                .execute(db)
                try seed(db)
            }

            try migrate()

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                  │
                │   type: .table,                                                                                │
                │   name: "children",                                                                            │
                │   tableName: "children",                                                                       │
                │   sql: """                                                                                     │
                │   CREATE TABLE "children" (                                                                    │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), -- No autoincrement │
                │     "title" TEXT COLLATE NOCASE NOT NULL DEFAULT (''),                                         │
                │     "parentID" TEXT NOT NULL REFERENCES "parents"("id") ON DELETE CASCADE,                     │
                │     "exclaimedTitle" TEXT NOT NULL AS ("title" || '!') STORED                                  │
                │   ) STRICT                                                                                     │
                │   """                                                                                          │
                │ )                                                                                              │
                ├────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                  │
                │   type: .table,                                                                                │
                │   name: "parents",                                                                             │
                │   tableName: "parents",                                                                        │
                │   sql: """                                                                                     │
                │   CREATE TABLE "parents" (                                                                     │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()),                     │
                │     "title" TEXT NOT NULL CHECK(length("title") > 0)                                           │
                │   ) STRICT                                                                                     │
                │   """                                                                                          │
                │ )                                                                                              │
                ├────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                  │
                │   type: .table,                                                                                │
                │   name: "tags",                                                                                │
                │   tableName: "tags",                                                                           │
                │   sql: """                                                                                     │
                │   CREATE TABLE "tags" (                                                                        │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()),                     │
                │     "title" TEXT NOT NULL UNIQUE                                                               │
                │   ) STRICT                                                                                     │
                │   """                                                                                          │
                │ )                                                                                              │
                └────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            assertQuery(Parent.all, database: database) {
                """
                ┌────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7), │
                │   title: "foo"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6), │
                │   title: "bar"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6), │
                │   title: "baz"                                             │
                │ )                                                          │
                └────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Child.all, database: database) {
                """
                ┌─────────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(d66c67a9-39cd-8786-75a9-1c47f5c0e47f),      │
                │   title: "foo",                                                 │
                │   parentID: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(98219b0b-627e-b12b-8e8f-08ed4a7959bf),      │
                │   title: "bar",                                                 │
                │   parentID: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(7eae27fe-b38d-3806-6aa4-6f953c251bea),      │
                │   title: "baz",                                                 │
                │   parentID: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6) │
                │ )                                                               │
                └─────────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Tag.select(\.title), database: database) {
                """
                ┌────────────┐
                │ "business" │
                │ "personal" │
                └────────────┘
                """
            }
        }

        @Test func `preserves top-level constraints`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "parents" (
                      "id" INTEGER,
                      "title" TEXT NOT NULL,

                      PRIMARY KEY("id"),
                      UNIQUE("title")
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "children" (
                      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                      "title" TEXT NOT NULL,
                      "parentID" INTEGER NOT NULL,

                      CHECK("id" > 0 AND length("title") > 0),
                      FOREIGN KEY ("parentID") REFERENCES "parents"("id") ON DELETE CASCADE
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "tags" (
                      "title" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try seed(db)
            }

            try migrate()

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "children",                                                        │
                │   tableName: "children",                                                   │
                │   sql: """                                                                 │
                │   CREATE TABLE "children" (                                                │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL,                                                 │
                │     "parentID" TEXT NOT NULL,                                              │
                │                                                                            │
                │     CHECK("id" > 0 AND length("title") > 0),                               │
                │     FOREIGN KEY ("parentID") REFERENCES "parents"("id") ON DELETE CASCADE  │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "parents",                                                         │
                │   tableName: "parents",                                                    │
                │   sql: """                                                                 │
                │   CREATE TABLE "parents" (                                                 │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL,                                                 │
                │     UNIQUE("title")                                                        │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "tags",                                                            │
                │   tableName: "tags",                                                       │
                │   sql: """                                                                 │
                │   CREATE TABLE "tags" (                                                    │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL                                                  │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                └────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            assertQuery(Parent.all, database: database) {
                """
                ┌────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7), │
                │   title: "foo"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6), │
                │   title: "bar"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6), │
                │   title: "baz"                                             │
                │ )                                                          │
                └────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Child.all, database: database) {
                """
                ┌─────────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(d66c67a9-39cd-8786-75a9-1c47f5c0e47f),      │
                │   title: "foo",                                                 │
                │   parentID: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(98219b0b-627e-b12b-8e8f-08ed4a7959bf),      │
                │   title: "bar",                                                 │
                │   parentID: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(7eae27fe-b38d-3806-6aa4-6f953c251bea),      │
                │   title: "baz",                                                 │
                │   parentID: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6) │
                │ )                                                               │
                └─────────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Tag.select(\.title), database: database) {
                """
                ┌────────────┐
                │ "personal" │
                │ "business" │
                └────────────┘
                """
            }
        }

        @Test func `preserves comments and newlines`() throws {
            try database.write { db in
                try #sql(
                    """
                    -- Comment
                    CREATE TABLE "parents" ( -- Comment
                      -- Comment
                      "id" INTEGER -- Comment
                        -- Comment
                        PRIMARY KEY -- Comment
                        -- Comment
                        AUTOINCREMENT, -- Comment
                      -- Comment
                      "title" TEXT NOT NULL -- Comment
                      -- Comment
                    ) STRICT -- Comment
                    -- Comment
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "children" (
                      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                      "title" TEXT NOT NULL,
                      "parentID" INTEGER 
                        NOT NULL 
                        REFERENCES "parents"("id") 
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "tags" (
                      "title" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try seed(db)
            }

            try migrate()

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌───────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                         │
                │   type: .table,                                                                       │
                │   name: "children",                                                                   │
                │   tableName: "children",                                                              │
                │   sql: """                                                                            │
                │   CREATE TABLE "children" (                                                           │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()),            │
                │     "title" TEXT NOT NULL,                                                            │
                │     "parentID" TEXT                                                                   │
                │       NOT NULL                                                                        │
                │       REFERENCES "parents"("id")                                                      │
                │       ON DELETE CASCADE                                                               │
                │       ON UPDATE CASCADE                                                               │
                │   ) STRICT                                                                            │
                │   """                                                                                 │
                │ )                                                                                     │
                ├───────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                         │
                │   type: .table,                                                                       │
                │   name: "parents",                                                                    │
                │   tableName: "parents",                                                               │
                │   sql: """                                                                            │
                │   CREATE TABLE "parents" ( -- Comment                                                 │
                │     -- Comment                                                                        │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), -- Comment │
                │     -- Comment                                                                        │
                │     "title" TEXT NOT NULL -- Comment                                                  │
                │     -- Comment                                                                        │
                │   ) STRICT -- Comment                                                                 │
                │   -- Comment                                                                          │
                │   """                                                                                 │
                │ )                                                                                     │
                ├───────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                         │
                │   type: .table,                                                                       │
                │   name: "tags",                                                                       │
                │   tableName: "tags",                                                                  │
                │   sql: """                                                                            │
                │   CREATE TABLE "tags" (                                                               │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()),            │
                │     "title" TEXT NOT NULL                                                             │
                │   ) STRICT                                                                            │
                │   """                                                                                 │
                │ )                                                                                     │
                └───────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            assertQuery(Parent.all, database: database) {
                """
                ┌────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7), │
                │   title: "foo"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6), │
                │   title: "bar"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6), │
                │   title: "baz"                                             │
                │ )                                                          │
                └────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Child.all, database: database) {
                """
                ┌─────────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(d66c67a9-39cd-8786-75a9-1c47f5c0e47f),      │
                │   title: "foo",                                                 │
                │   parentID: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(98219b0b-627e-b12b-8e8f-08ed4a7959bf),      │
                │   title: "bar",                                                 │
                │   parentID: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(7eae27fe-b38d-3806-6aa4-6f953c251bea),      │
                │   title: "baz",                                                 │
                │   parentID: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6) │
                │ )                                                               │
                └─────────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Tag.select(\.title), database: database) {
                """
                ┌────────────┐
                │ "personal" │
                │ "business" │
                └────────────┘
                """
            }
        }

        @Test func `rejects a non-integer primary key`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "phoneNumbers" (
                      "number" TEXT NOT NULL PRIMARY KEY
                    )
                    """
                )
                .execute(db)
                try #sql(
                    """
                    INSERT INTO "phoneNumbers"
                    VALUES
                    ('212-555-1234')
                    """
                )
                .execute(db)
            }

            let error = #expect(throws: (any Error).self) {
                try migrate(tables: PhoneNumber.self)
            }
            assertInlineSnapshot(of: error?.localizedDescription, as: .customDump) {
                """
                "Invalid primary key. The table must have either no primary key or a single integer primary key to migrate."
                """
            }
            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────┐
                │ SQLiteSchema(                          │
                │   type: .table,                        │
                │   name: "phoneNumbers",                │
                │   tableName: "phoneNumbers",           │
                │   sql: """                             │
                │   CREATE TABLE "phoneNumbers" (        │
                │     "number" TEXT NOT NULL PRIMARY KEY │
                │   )                                    │
                │   """                                  │
                │ )                                      │
                └────────────────────────────────────────┘
                """#
            }
            assertQuery(PhoneNumber.all, database: database) {
                """
                ┌──────────────────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.PhoneNumber(number: "212-555-1234") │
                └──────────────────────────────────────────────────────────────────────────┘
                """
            }
        }

        @Test func `rejects a compound primary key`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "parents" (
                      "id" INTEGER,
                      "title" TEXT NOT NULL,

                      PRIMARY KEY("id", "title")
                    ) STRICT
                    """
                )
                .execute(db)
            }

            let error = #expect(throws: (any Error).self) {
                try migrate(tables: Parent.self)
            }
            assertInlineSnapshot(of: error?.localizedDescription, as: .customDump) {
                """
                "Invalid primary key. The table must have either no primary key or a single integer primary key to migrate."
                """
            }
        }

        @Test func `adds a primary key with a custom name`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "users" (
                      "name" TEXT NOT NULL
                    )
                    """
                )
                .execute(db)
                try #sql(
                    """
                    INSERT INTO "users"
                    VALUES
                    ('blob'), ('blob jr'), ('blob sr')
                    """
                )
                .execute(db)
            }

            try migrate(tables: User.self)

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                      │
                │   type: .table,                                                                    │
                │   name: "users",                                                                   │
                │   tableName: "users",                                                              │
                │   sql: """                                                                         │
                │   CREATE TABLE "users" (                                                           │
                │     "identifier" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "name" TEXT NOT NULL                                                           │
                │   )                                                                                │
                │   """                                                                              │
                │ )                                                                                  │
                └────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            assertQuery(User.select(\.name), database: database) {
                """
                ┌───────────┐
                │ "blob"    │
                │ "blob jr" │
                │ "blob sr" │
                └───────────┘
                """
            }
        }

        @Test func `recreates indices and triggers`() throws {
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "parents" (
                      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                      "title" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE INDEX "parents_name" ON "parents"("title")
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TRIGGER "parents_trigger" AFTER UPDATE ON "parents" BEGIN
                      SELECT 1;
                    END
                    """
                )
                .execute(db)
            }

            try migrate(tables: Parent.self)

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "parents",                                                         │
                │   tableName: "parents",                                                    │
                │   sql: """                                                                 │
                │   CREATE TABLE "parents" (                                                 │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     "title" TEXT NOT NULL                                                  │
                │   ) STRICT                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .index,                                                            │
                │   name: "parents_name",                                                    │
                │   tableName: "parents",                                                    │
                │   sql: #"CREATE INDEX "parents_name" ON "parents"("title")"#               │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .trigger,                                                          │
                │   name: "parents_trigger",                                                 │
                │   tableName: "parents",                                                    │
                │   sql: """                                                                 │
                │   CREATE TRIGGER "parents_trigger" AFTER UPDATE ON "parents" BEGIN         │
                │     SELECT 1;                                                              │
                │   END                                                                      │
                │   """                                                                      │
                │ )                                                                          │
                └────────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Test func `migrates lowercase unquoted schemas`() throws {
            try database.write { db in
                try #sql(
                    """
                    create table parents (
                      id integer primary key autoincrement,
                      title text not null
                    ) strict
                    """
                )
                .execute(db)
                try #sql(
                    """
                    create table children (
                      id integer primary key autoincrement,
                      title text not null,
                      parentID integer not null references parents(id) on delete cascade
                    ) strict
                    """
                )
                .execute(db)
                try #sql(
                    """
                    create table tags (
                      title text not null
                    ) strict
                    """
                )
                .execute(db)
                try seed(db)
            }

            try migrate()

            assertQuery(SQLiteSchema.userObjects, database: database) {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "children",                                                        │
                │   tableName: "children",                                                   │
                │   sql: """                                                                 │
                │   CREATE TABLE "children" (                                                │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     title text not null,                                                   │
                │     parentID TEXT not null references parents(id) on delete cascade        │
                │   ) strict                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "parents",                                                         │
                │   tableName: "parents",                                                    │
                │   sql: """                                                                 │
                │   CREATE TABLE "parents" (                                                 │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     title text not null                                                    │
                │   ) strict                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                ├────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                              │
                │   type: .table,                                                            │
                │   name: "tags",                                                            │
                │   tableName: "tags",                                                       │
                │   sql: """                                                                 │
                │   CREATE TABLE "tags" (                                                    │
                │     "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT ("uuid"()), │
                │     title text not null                                                    │
                │   ) strict                                                                 │
                │   """                                                                      │
                │ )                                                                          │
                └────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            assertQuery(Parent.all, database: database) {
                """
                ┌────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7), │
                │   title: "foo"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6), │
                │   title: "bar"                                             │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Parent(               │
                │   id: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6), │
                │   title: "baz"                                             │
                │ )                                                          │
                └────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Child.all, database: database) {
                """
                ┌─────────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(d66c67a9-39cd-8786-75a9-1c47f5c0e47f),      │
                │   title: "foo",                                                 │
                │   parentID: RFC_4122.UUID(8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(98219b0b-627e-b12b-8e8f-08ed4a7959bf),      │
                │   title: "bar",                                                 │
                │   parentID: RFC_4122.UUID(c9e96bbb-4af3-0821-78da-a7dfb992d9e6) │
                │ )                                                               │
                ├─────────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Child(                     │
                │   id: RFC_4122.UUID(7eae27fe-b38d-3806-6aa4-6f953c251bea),      │
                │   title: "baz",                                                 │
                │   parentID: RFC_4122.UUID(b0a18942-23c0-1c82-0c94-71836acd1bb6) │
                │ )                                                               │
                └─────────────────────────────────────────────────────────────────┘
                """
            }
            assertQuery(Tag.all, database: database) {
                """
                ┌────────────────────────────────────────────────────────────┐
                │ SQLite_Tests.`Primary key migration`.Tag(                  │
                │   id: RFC_4122.UUID(00000000-0000-0000-0000-000000000001), │
                │   title: "personal"                                        │
                │ )                                                          │
                ├────────────────────────────────────────────────────────────┤
                │ SQLite_Tests.`Primary key migration`.Tag(                  │
                │   id: RFC_4122.UUID(00000000-0000-0000-0000-000000000002), │
                │   title: "business"                                        │
                │ )                                                          │
                └────────────────────────────────────────────────────────────┘
                """
            }
        }

        private func seed(_ db: Database) throws {
            try #sql(
                """
                INSERT INTO "parents"
                ("title")
                VALUES
                ('foo'), ('bar'), ('baz')
                """
            )
            .execute(db)
            try #sql(
                """
                INSERT INTO "children"
                ("title", "parentID")
                VALUES
                ('foo', 1), ('bar', 2), ('baz', 3) 
                """
            )
            .execute(db)
            try #sql(
                """
                INSERT INTO "tags"
                ("title")
                VALUES
                ('personal'), ('business')
                """
            )
            .execute(db)
        }

        private func migrate() throws {
            try migrate(tables: Parent.self, Child.self, Tag.self)
        }

        private func migrate<each T: PrimaryKeyedTable>(
            tables: repeat (each T).Type
        ) throws
        where
            repeat (each T).PrimaryKey.QueryOutput: IdentifierStringConvertible,
            repeat (each T).TableColumns.PrimaryColumn: TableColumnExpression
        {
            try database.writeWithoutTransaction { db in
                try #sql("PRAGMA foreign_keys = OFF").execute(db)
                try db.inTransaction {
                    try SyncEngine.migratePrimaryKeys(
                        db,
                        tables: repeat each tables,
                        uuid: $uuid
                    )
                    return .commit
                }
                try #sql("PRAGMA foreign_keys = ON").execute(db)
            }
        }
    }

    extension SQLiteSchema {
        fileprivate static let userObjects =
            Self
            .where { !$0.name.like("sqlite_%") }
            .order(by: \.name)
    }
#endif
