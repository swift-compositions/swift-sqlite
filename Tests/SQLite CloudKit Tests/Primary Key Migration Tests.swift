#if CloudKit && canImport(CloudKit)
    import CloudKit
    import Foundation
    import ISO_9075_Call_Level_Interface
    import RFC_4122
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_CloudKit
    import SQLite_Test_Support
    import Testing
    import Tests_Inline_Snapshot

    @Suite(.timeLimit(.minutes(5))) struct `Primary key migration` {
        @Table("parents") struct Parent: Identifiable {
            let id: IETF.RFC.`4122`.UUID
            var title = ""
        }
        @Table("children") struct Child {
            let id: IETF.RFC.`4122`.UUID
            var title = ""
            var parentID: Parent.ID
        }
        @Table("tags") struct Tag {
            let id: IETF.RFC.`4122`.UUID
            var title = ""
        }
        @Table("phoneNumbers") struct PhoneNumber {
            @Column(primaryKey: true)
            let number: String
        }
        @Table("users") struct User {
            @Column(primaryKey: true)
            let identifier: IETF.RFC.`4122`.UUID
            var name = ""
        }
        let database: SQLite.Database
        let incrementingUUID = IncrementingUUID()

        init() async throws {
            database = try SQLite.Database()
            try await database.writeWithoutTransaction { db in
                db.add(function: $uuid)
                db.add(function: $customUUID)
            }
        }

        @DatabaseFunction
        func uuid() -> IETF.RFC.`4122`.UUID {
            incrementingUUID()
        }

        @DatabaseFunction
        func customUUID() -> IETF.RFC.`4122`.UUID {
            incrementingUUID()
        }

        @Test func `migrates integer primary keys, foreign keys and missing primary keys to UUIDs`() async throws {
            try await database.write { db in
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

            try await migrate()

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                                                                                                           │
                │   type: .table,                                                                                                                                                                                                                         │
                │   name: "children",                                                                                                                                                                                                                     │
                │   tableName: "children",                                                                                                                                                                                                                │
                │   sql: "CREATE TABLE \"children\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL,\n  \"parentID\" TEXT NOT NULL REFERENCES \"parents\"(\"id\") ON DELETE CASCADE\n) STRICT" │
                │ )                                                                                                                                                                                                                                       │
                ├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                           │
                │   type: .table,                                                                                                                                                                                                                         │
                │   name: "parents",                                                                                                                                                                                                                      │
                │   tableName: "parents",                                                                                                                                                                                                                 │
                │   sql: "CREATE TABLE \"parents\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL\n) STRICT"                                                                                  │
                │ )                                                                                                                                                                                                                                       │
                ├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                           │
                │   type: .table,                                                                                                                                                                                                                         │
                │   name: "tags",                                                                                                                                                                                                                         │
                │   tableName: "tags",                                                                                                                                                                                                                    │
                │   sql: "CREATE TABLE \"tags\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL\n) STRICT"                                                                                     │
                │ )                                                                                                                                                                                                                                       │
                └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Parent.all
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Parent(                                     │
                │   id: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7, │
                │   title: "foo"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: c9e96bbb-4af3-0821-78da-a7dfb992d9e6, │
                │   title: "bar"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: b0a18942-23c0-1c82-0c94-71836acd1bb6, │
                │   title: "baz"                              │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Child.all
            } matches: {
                """
                ┌──────────────────────────────────────────────────┐
                │ Child(                                           │
                │   id: d66c67a9-39cd-8786-75a9-1c47f5c0e47f,      │
                │   title: "foo",                                  │
                │   parentID: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 98219b0b-627e-b12b-8e8f-08ed4a7959bf,      │
                │   title: "bar",                                  │
                │   parentID: c9e96bbb-4af3-0821-78da-a7dfb992d9e6 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 7eae27fe-b38d-3806-6aa4-6f953c251bea,      │
                │   title: "baz",                                  │
                │   parentID: b0a18942-23c0-1c82-0c94-71836acd1bb6 │
                │ )                                                │
                └──────────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Tag.all
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Tag(                                        │
                │   id: 00000000-0000-0000-0000-000000000001, │
                │   title: "personal"                         │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Tag(                                        │
                │   id: 00000000-0000-0000-0000-000000000002, │
                │   title: "business"                         │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
        }

        @Test func `preserves the rowid`() async throws {
            try await database.write { db in
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

            try await migrate(tables: Parent.self)

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Parent.select { ($0.rowid, $0) }
            } matches: {
                """
                ┌──────┬─────────────────────────────────────────────┐
                │ 1    │ Parent(                                     │
                │      │   id: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7, │
                │      │   title: "blob"                             │
                │      │ )                                           │
                ├──────┼─────────────────────────────────────────────┤
                │ 1000 │ Parent(                                     │
                │      │   id: ec5f9355-c981-e3c7-3246-09a01e0c4897, │
                │      │   title: "blob jr"                          │
                │      │ )                                           │
                └──────┴─────────────────────────────────────────────┘
                """
            }
        }

        @Test func `rejects a primary key that is already a UUID`() async throws {
            try await database.write { db in
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

            let error = await #expect(throws: (any Swift.Error).self) {
                try await migrate(tables: Parent.self)
            }
            await snapshot(as: .state) {
                error?.localizedDescription
            } matches: {
                """
                "Invalid primary key. The table must have either no primary key or a single integer primary key to migrate."
                """
            }

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                      │
                │   type: .table,                                                                                                                                    │
                │   name: "parents",                                                                                                                                 │
                │   tableName: "parents",                                                                                                                            │
                │   sql: "CREATE TABLE \"parents\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),\n  \"title\" TEXT NOT NULL\n) STRICT" │
                │ )                                                                                                                                                  │
                └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Test func `drops unique constraints`() async throws {
            try await database.write { db in
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

            try await database.writeWithoutTransaction { db in
                try #sql("PRAGMA foreign_keys = OFF").execute(db)
                try db.transaction {
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

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                                                  │
                │   type: .table,                                                                                                                                                                │
                │   name: "tags",                                                                                                                                                                │
                │   tableName: "tags",                                                                                                                                                           │
                │   sql: "CREATE TABLE \"tags\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL,\n  \"name\" TEXT NOT NULL\n) STRICT" │
                │ )                                                                                                                                                                              │
                ├────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                  │
                │   type: .table,                                                                                                                                                                │
                │   name: "users",                                                                                                                                                               │
                │   tableName: "users",                                                                                                                                                          │
                │   sql: "CREATE TABLE \"users\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL) STRICT"                             │
                │ )                                                                                                                                                                              │
                └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Table("users") struct PrimaryKeyNamedUnique {
            @Column(primaryKey: true)
            let unique: IETF.RFC.`4122`.UUID
            var title = ""
        }
        @Test func `migrates a primary key named unique`() async throws {
            try await database.write { db in
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

            try await database.writeWithoutTransaction { db in
                try #sql("PRAGMA foreign_keys = OFF").execute(db)
                try db.transaction {
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

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                          │
                │   type: .table,                                                                                                                                        │
                │   name: "users",                                                                                                                                       │
                │   tableName: "users",                                                                                                                                  │
                │   sql: "CREATE TABLE \"users\" (\n  \"unique\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL) STRICT" │
                │ )                                                                                                                                                      │
                └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Test func `preserves column constraints`() async throws {
            try await database.write { db in
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

            try await migrate()

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                                                                                                                                                                                                                                 │
                │   type: .table,                                                                                                                                                                                                                                                                                                                                               │
                │   name: "children",                                                                                                                                                                                                                                                                                                                                           │
                │   tableName: "children",                                                                                                                                                                                                                                                                                                                                      │
                │   sql: "CREATE TABLE \"children\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()), -- No autoincrement\n  \"title\" TEXT COLLATE NOCASE NOT NULL DEFAULT (\'\'),\n  \"parentID\" TEXT NOT NULL REFERENCES \"parents\"(\"id\") ON DELETE CASCADE,\n  \"exclaimedTitle\" TEXT NOT NULL AS (\"title\" || \'!\') STORED\n) STRICT" │
                │ )                                                                                                                                                                                                                                                                                                                                                             │
                ├───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                                                                                                                                                 │
                │   type: .table,                                                                                                                                                                                                                                                                                                                                               │
                │   name: "parents",                                                                                                                                                                                                                                                                                                                                            │
                │   tableName: "parents",                                                                                                                                                                                                                                                                                                                                       │
                │   sql: "CREATE TABLE \"parents\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL CHECK(length(\"title\") > 0)\n) STRICT"                                                                                                                                                                           │
                │ )                                                                                                                                                                                                                                                                                                                                                             │
                ├───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                                                                                                                                                 │
                │   type: .table,                                                                                                                                                                                                                                                                                                                                               │
                │   name: "tags",                                                                                                                                                                                                                                                                                                                                               │
                │   tableName: "tags",                                                                                                                                                                                                                                                                                                                                          │
                │   sql: "CREATE TABLE \"tags\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL UNIQUE\n) STRICT"                                                                                                                                                                                                    │
                │ )                                                                                                                                                                                                                                                                                                                                                             │
                └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Parent.all
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Parent(                                     │
                │   id: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7, │
                │   title: "foo"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: c9e96bbb-4af3-0821-78da-a7dfb992d9e6, │
                │   title: "bar"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: b0a18942-23c0-1c82-0c94-71836acd1bb6, │
                │   title: "baz"                              │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Child.all
            } matches: {
                """
                ┌──────────────────────────────────────────────────┐
                │ Child(                                           │
                │   id: d66c67a9-39cd-8786-75a9-1c47f5c0e47f,      │
                │   title: "foo",                                  │
                │   parentID: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 98219b0b-627e-b12b-8e8f-08ed4a7959bf,      │
                │   title: "bar",                                  │
                │   parentID: c9e96bbb-4af3-0821-78da-a7dfb992d9e6 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 7eae27fe-b38d-3806-6aa4-6f953c251bea,      │
                │   title: "baz",                                  │
                │   parentID: b0a18942-23c0-1c82-0c94-71836acd1bb6 │
                │ )                                                │
                └──────────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Tag.select(\.title)
            } matches: {
                """
                ┌────────────┐
                │ "business" │
                │ "personal" │
                └────────────┘
                """
            }
        }

        @Test func `preserves top-level constraints`() async throws {
            try await database.write { db in
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

            try await migrate()

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                                                                                                                                                                                            │
                │   type: .table,                                                                                                                                                                                                                                                                                                          │
                │   name: "children",                                                                                                                                                                                                                                                                                                      │
                │   tableName: "children",                                                                                                                                                                                                                                                                                                 │
                │   sql: "CREATE TABLE \"children\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL,\n  \"parentID\" TEXT NOT NULL,\n\n  CHECK(\"id\" > 0 AND length(\"title\") > 0),\n  FOREIGN KEY (\"parentID\") REFERENCES \"parents\"(\"id\") ON DELETE CASCADE\n) STRICT" │
                │ )                                                                                                                                                                                                                                                                                                                        │
                ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                                                                                                            │
                │   type: .table,                                                                                                                                                                                                                                                                                                          │
                │   name: "parents",                                                                                                                                                                                                                                                                                                       │
                │   tableName: "parents",                                                                                                                                                                                                                                                                                                  │
                │   sql: "CREATE TABLE \"parents\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL,\n  UNIQUE(\"title\")\n) STRICT"                                                                                                                                             │
                │ )                                                                                                                                                                                                                                                                                                                        │
                ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                                                                                                            │
                │   type: .table,                                                                                                                                                                                                                                                                                                          │
                │   name: "tags",                                                                                                                                                                                                                                                                                                          │
                │   tableName: "tags",                                                                                                                                                                                                                                                                                                     │
                │   sql: "CREATE TABLE \"tags\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL\n) STRICT"                                                                                                                                                                      │
                │ )                                                                                                                                                                                                                                                                                                                        │
                └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Parent.all
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Parent(                                     │
                │   id: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7, │
                │   title: "foo"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: c9e96bbb-4af3-0821-78da-a7dfb992d9e6, │
                │   title: "bar"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: b0a18942-23c0-1c82-0c94-71836acd1bb6, │
                │   title: "baz"                              │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Child.all
            } matches: {
                """
                ┌──────────────────────────────────────────────────┐
                │ Child(                                           │
                │   id: d66c67a9-39cd-8786-75a9-1c47f5c0e47f,      │
                │   title: "foo",                                  │
                │   parentID: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 98219b0b-627e-b12b-8e8f-08ed4a7959bf,      │
                │   title: "bar",                                  │
                │   parentID: c9e96bbb-4af3-0821-78da-a7dfb992d9e6 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 7eae27fe-b38d-3806-6aa4-6f953c251bea,      │
                │   title: "baz",                                  │
                │   parentID: b0a18942-23c0-1c82-0c94-71836acd1bb6 │
                │ )                                                │
                └──────────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Tag.select(\.title)
            } matches: {
                """
                ┌────────────┐
                │ "personal" │
                │ "business" │
                └────────────┘
                """
            }
        }

        @Test func `preserves comments and newlines`() async throws {
            try await database.write { db in
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

            try await migrate()

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                                                                                                                                                    │
                │   type: .table,                                                                                                                                                                                                                                                                  │
                │   name: "children",                                                                                                                                                                                                                                                              │
                │   tableName: "children",                                                                                                                                                                                                                                                         │
                │   sql: "CREATE TABLE \"children\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL,\n  \"parentID\" TEXT \n    NOT NULL \n    REFERENCES \"parents\"(\"id\") \n    ON DELETE CASCADE\n    ON UPDATE CASCADE\n) STRICT" │
                │ )                                                                                                                                                                                                                                                                                │
                ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                                                                    │
                │   type: .table,                                                                                                                                                                                                                                                                  │
                │   name: "parents",                                                                                                                                                                                                                                                               │
                │   tableName: "parents",                                                                                                                                                                                                                                                          │
                │   sql: "CREATE TABLE \"parents\" ( -- Comment\n  -- Comment\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()), -- Comment\n  -- Comment\n  \"title\" TEXT NOT NULL -- Comment\n  -- Comment\n) STRICT -- Comment\n-- Comment"                         │
                │ )                                                                                                                                                                                                                                                                                │
                ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                                                                                    │
                │   type: .table,                                                                                                                                                                                                                                                                  │
                │   name: "tags",                                                                                                                                                                                                                                                                  │
                │   tableName: "tags",                                                                                                                                                                                                                                                             │
                │   sql: "CREATE TABLE \"tags\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL\n) STRICT"                                                                                                                              │
                │ )                                                                                                                                                                                                                                                                                │
                └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Parent.all
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Parent(                                     │
                │   id: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7, │
                │   title: "foo"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: c9e96bbb-4af3-0821-78da-a7dfb992d9e6, │
                │   title: "bar"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: b0a18942-23c0-1c82-0c94-71836acd1bb6, │
                │   title: "baz"                              │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Child.all
            } matches: {
                """
                ┌──────────────────────────────────────────────────┐
                │ Child(                                           │
                │   id: d66c67a9-39cd-8786-75a9-1c47f5c0e47f,      │
                │   title: "foo",                                  │
                │   parentID: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 98219b0b-627e-b12b-8e8f-08ed4a7959bf,      │
                │   title: "bar",                                  │
                │   parentID: c9e96bbb-4af3-0821-78da-a7dfb992d9e6 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 7eae27fe-b38d-3806-6aa4-6f953c251bea,      │
                │   title: "baz",                                  │
                │   parentID: b0a18942-23c0-1c82-0c94-71836acd1bb6 │
                │ )                                                │
                └──────────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Tag.select(\.title)
            } matches: {
                """
                ┌────────────┐
                │ "personal" │
                │ "business" │
                └────────────┘
                """
            }
        }

        @Test func `rejects a non-integer primary key`() async throws {
            try await database.write { db in
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

            let error = await #expect(throws: (any Swift.Error).self) {
                try await migrate(tables: PhoneNumber.self)
            }
            await snapshot(as: .state) {
                error?.localizedDescription
            } matches: {
                """
                "Invalid primary key. The table must have either no primary key or a single integer primary key to migrate."
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌─────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                       │
                │   type: .table,                                                                     │
                │   name: "phoneNumbers",                                                             │
                │   tableName: "phoneNumbers",                                                        │
                │   sql: "CREATE TABLE \"phoneNumbers\" (\n  \"number\" TEXT NOT NULL PRIMARY KEY\n)" │
                │ )                                                                                   │
                └─────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                PhoneNumber.all
            } matches: {
                """
                ┌──────────────────────────┐
                │ PhoneNumber(             │
                │   number: "212-555-1234" │
                │ )                        │
                └──────────────────────────┘
                """
            }
        }

        @Test func `rejects a compound primary key`() async throws {
            try await database.write { db in
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

            let error = await #expect(throws: (any Swift.Error).self) {
                try await migrate(tables: Parent.self)
            }
            await snapshot(as: .state) {
                error?.localizedDescription
            } matches: {
                """
                "Invalid primary key. The table must have either no primary key or a single integer primary key to migrate."
                """
            }
        }

        @Test func `adds a primary key with a custom name`() async throws {
            try await database.write { db in
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

            try await migrate(tables: User.self)

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                        │
                │   type: .table,                                                                                                                                      │
                │   name: "users",                                                                                                                                     │
                │   tableName: "users",                                                                                                                                │
                │   sql: "CREATE TABLE \"users\" (\n  \"identifier\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"name\" TEXT NOT NULL\n)" │
                │ )                                                                                                                                                    │
                └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                User.select(\.name)
            } matches: {
                """
                ┌───────────┐
                │ "blob"    │
                │ "blob jr" │
                │ "blob sr" │
                └───────────┘
                """
            }
        }

        @Test func `recreates indices and triggers`() async throws {
            try await database.write { db in
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

            try await migrate(tables: Parent.self)

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                          │
                │   type: .table,                                                                                                                                        │
                │   name: "parents",                                                                                                                                     │
                │   tableName: "parents",                                                                                                                                │
                │   sql: "CREATE TABLE \"parents\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  \"title\" TEXT NOT NULL\n) STRICT" │
                │ )                                                                                                                                                      │
                ├────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                          │
                │   type: .index,                                                                                                                                        │
                │   name: "parents_name",                                                                                                                                │
                │   tableName: "parents",                                                                                                                                │
                │   sql: "CREATE INDEX \"parents_name\" ON \"parents\"(\"title\")"                                                                                       │
                │ )                                                                                                                                                      │
                ├────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                          │
                │   type: .trigger,                                                                                                                                      │
                │   name: "parents_trigger",                                                                                                                             │
                │   tableName: "parents",                                                                                                                                │
                │   sql: "CREATE TRIGGER \"parents_trigger\" AFTER UPDATE ON \"parents\" BEGIN\n  SELECT 1;\nEND"                                                        │
                │ )                                                                                                                                                      │
                └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
        }

        @Test func `migrates lowercase unquoted schemas`() async throws {
            try await database.write { db in
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

            try await migrate()

            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                SQLiteSchema.userObjects
            } matches: {
                #"""
                ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
                │ SQLiteSchema(                                                                                                                                                                                                           │
                │   type: .table,                                                                                                                                                                                                         │
                │   name: "children",                                                                                                                                                                                                     │
                │   tableName: "children",                                                                                                                                                                                                │
                │   sql: "CREATE TABLE \"children\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  title text not null,\n  parentID TEXT not null references parents(id) on delete cascade\n) strict" │
                │ )                                                                                                                                                                                                                       │
                ├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                           │
                │   type: .table,                                                                                                                                                                                                         │
                │   name: "parents",                                                                                                                                                                                                      │
                │   tableName: "parents",                                                                                                                                                                                                 │
                │   sql: "CREATE TABLE \"parents\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  title text not null\n) strict"                                                                      │
                │ )                                                                                                                                                                                                                       │
                ├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
                │ SQLiteSchema(                                                                                                                                                                                                           │
                │   type: .table,                                                                                                                                                                                                         │
                │   name: "tags",                                                                                                                                                                                                         │
                │   tableName: "tags",                                                                                                                                                                                                    │
                │   sql: "CREATE TABLE \"tags\" (\n  \"id\" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (\"uuid\"()),\n  title text not null\n) strict"                                                                         │
                │ )                                                                                                                                                                                                                       │
                └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                """#
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Parent.all
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Parent(                                     │
                │   id: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7, │
                │   title: "foo"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: c9e96bbb-4af3-0821-78da-a7dfb992d9e6, │
                │   title: "bar"                              │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Parent(                                     │
                │   id: b0a18942-23c0-1c82-0c94-71836acd1bb6, │
                │   title: "baz"                              │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Child.all
            } matches: {
                """
                ┌──────────────────────────────────────────────────┐
                │ Child(                                           │
                │   id: d66c67a9-39cd-8786-75a9-1c47f5c0e47f,      │
                │   title: "foo",                                  │
                │   parentID: 8c0d1699-3f8b-f58b-f1c1-caa2c0efd5c7 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 98219b0b-627e-b12b-8e8f-08ed4a7959bf,      │
                │   title: "bar",                                  │
                │   parentID: c9e96bbb-4af3-0821-78da-a7dfb992d9e6 │
                │ )                                                │
                ├──────────────────────────────────────────────────┤
                │ Child(                                           │
                │   id: 7eae27fe-b38d-3806-6aa4-6f953c251bea,      │
                │   title: "baz",                                  │
                │   parentID: b0a18942-23c0-1c82-0c94-71836acd1bb6 │
                │ )                                                │
                └──────────────────────────────────────────────────┘
                """
            }
            await snapshot(as: .rows(in: database, drawing: State.draw)) {
                Tag.all
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Tag(                                        │
                │   id: 00000000-0000-0000-0000-000000000001, │
                │   title: "personal"                         │
                │ )                                           │
                ├─────────────────────────────────────────────┤
                │ Tag(                                        │
                │   id: 00000000-0000-0000-0000-000000000002, │
                │   title: "business"                         │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
        }

        private func seed(_ db: borrowing SQLite.Connection) throws {
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

        private func migrate() async throws {
            try await migrate(tables: Parent.self, Child.self, Tag.self)
        }

        private func migrate<each T: PrimaryKeyedTable>(
            tables: repeat (each T).Type
        ) async throws
        where
            repeat (each T).PrimaryKey.QueryOutput: IdentifierStringConvertible,
            repeat (each T).TableColumns.PrimaryColumn: TableColumnExpression
        {
            // What the migration throws comes out as it was thrown.
            try await database.writeWithoutTransaction { db in
                try #sql("PRAGMA foreign_keys = OFF").execute(db)
                try db.transaction {
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
