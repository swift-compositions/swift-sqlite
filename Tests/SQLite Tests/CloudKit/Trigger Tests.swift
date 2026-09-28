#if CloudKit
    import CloudKit
    import InlineSnapshotTesting
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Trigger generation`: CloudKitTestBase, @unchecked Sendable {
            @Test func `installs, drops and reinstalls the synchronization triggers`() async throws {
                let triggersAfterSetUp = try await userDatabase.userWrite { db in
                    try #sql("SELECT sql FROM sqlite_temp_master ORDER BY sql", as: String?.self).fetchAll(db)
                }
                assertInlineSnapshot(of: triggersAfterSetUp, as: .customDump) {
                    #"""
                    [
                      [0]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_childWithOnDeleteSetDefaults_from_sync_engine"
                      AFTER DELETE ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [1]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_childWithOnDeleteSetDefaults_from_user"
                      AFTER DELETE ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [2]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_childWithOnDeleteSetNulls_from_sync_engine"
                      AFTER DELETE ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [3]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_childWithOnDeleteSetNulls_from_user"
                      AFTER DELETE ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [4]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_modelAs_from_sync_engine"
                      AFTER DELETE ON "modelAs"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [5]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_modelAs_from_user"
                      AFTER DELETE ON "modelAs"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [6]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_modelBs_from_sync_engine"
                      AFTER DELETE ON "modelBs"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [7]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_modelBs_from_user"
                      AFTER DELETE ON "modelBs"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [8]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_modelCs_from_sync_engine"
                      AFTER DELETE ON "modelCs"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [9]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_modelCs_from_user"
                      AFTER DELETE ON "modelCs"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [10]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_parents_from_sync_engine"
                      AFTER DELETE ON "parents"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [11]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_parents_from_user"
                      AFTER DELETE ON "parents"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [12]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_reminderTags_from_sync_engine"
                      AFTER DELETE ON "reminderTags"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [13]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_reminderTags_from_user"
                      AFTER DELETE ON "reminderTags"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [14]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_remindersListAssets_from_sync_engine"
                      AFTER DELETE ON "remindersListAssets"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [15]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_remindersListAssets_from_user"
                      AFTER DELETE ON "remindersListAssets"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [16]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_remindersListPrivates_from_sync_engine"
                      AFTER DELETE ON "remindersListPrivates"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [17]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_remindersListPrivates_from_user"
                      AFTER DELETE ON "remindersListPrivates"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [18]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_remindersLists_from_sync_engine"
                      AFTER DELETE ON "remindersLists"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [19]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_remindersLists_from_user"
                      AFTER DELETE ON "remindersLists"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [20]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_reminders_from_sync_engine"
                      AFTER DELETE ON "reminders"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [21]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_reminders_from_user"
                      AFTER DELETE ON "reminders"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [22]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_scopedModels_from_sync_engine"
                      AFTER DELETE ON "scopedModels"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [23]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_scopedModels_from_user"
                      AFTER DELETE ON "scopedModels"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [24]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_sqlite_icloud_metadata"
                      AFTER UPDATE OF "_isDeleted" ON "sqlite_icloud_metadata"
                      FOR EACH ROW WHEN ((NOT ("old"."_isDeleted")) AND ("new"."_isDeleted")) AND (NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) BEGIN
                        SELECT "sqlite_icloud_didDelete"("new"."recordName", coalesce("new"."lastKnownServerRecord", (
                          WITH "ancestorMetadatas" AS (
                            SELECT "sqlite_icloud_metadata"."recordName" AS "recordName", "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."lastKnownServerRecord" AS "lastKnownServerRecord"
                            FROM "sqlite_icloud_metadata"
                            WHERE (("sqlite_icloud_metadata"."recordName") = ("new"."recordName"))
                              UNION ALL
                            SELECT "sqlite_icloud_metadata"."recordName" AS "recordName", "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."lastKnownServerRecord" AS "lastKnownServerRecord"
                            FROM "sqlite_icloud_metadata"
                            JOIN "ancestorMetadatas" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("ancestorMetadatas"."parentRecordName")
                          )
                          SELECT "ancestorMetadatas"."lastKnownServerRecord"
                          FROM "ancestorMetadatas"
                          WHERE (("ancestorMetadatas"."parentRecordName") IS NOT DISTINCT FROM (NULL))
                        )), "new"."share");
                      END
                      """,
                      [25]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_tags_from_sync_engine"
                      AFTER DELETE ON "tags"
                      FOR EACH ROW WHEN "sqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."title")) AND (("sqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [26]: """
                      CREATE TRIGGER "sqlite_icloud_after_delete_on_tags_from_user"
                      AFTER DELETE ON "tags"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."title")) AND (("sqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [27]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_childWithOnDeleteSetDefaults"
                      AFTER INSERT ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetDefaults', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [28]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_childWithOnDeleteSetNulls"
                      AFTER INSERT ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetNulls', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [29]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_modelAs"
                      AFTER INSERT ON "modelAs"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelAs', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [30]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_modelBs"
                      AFTER INSERT ON "modelBs"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelBs', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs'))))), '__defaultOwner__'), "new"."modelAID", 'modelAs'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [31]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_modelCs"
                      AFTER INSERT ON "modelCs"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelCs', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs'))))), '__defaultOwner__'), "new"."modelBID", 'modelBs'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [32]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_parents"
                      AFTER INSERT ON "parents"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'parents', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [33]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_reminderTags"
                      AFTER INSERT ON "reminderTags"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminderTags', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [34]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_reminders"
                      AFTER INSERT ON "reminders"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminders', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [35]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_remindersListAssets"
                      AFTER INSERT ON "remindersListAssets"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListAssets', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [36]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_remindersListPrivates"
                      AFTER INSERT ON "remindersListPrivates"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListPrivates', coalesce(coalesce('zone', "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce('__defaultOwner__', "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [37]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_remindersLists"
                      AFTER INSERT ON "remindersLists"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'remindersLists', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [38]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_scopedModels"
                      AFTER INSERT ON "scopedModels"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'scopedModels', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [39]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_sqlite_icloud_metadata"
                      AFTER INSERT ON "sqlite_icloud_metadata"
                      FOR EACH ROW WHEN NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.invalid-record-name-error')
                        WHERE NOT (((substr("new"."recordName", 1, 1)) <> ('_')) AND ((octet_length("new"."recordName")) <= (255))) AND ((octet_length("new"."recordName")) = (length("new"."recordName")));
                        SELECT "sqlite_icloud_didUpdate"("new"."recordName", "new"."zoneName", "new"."ownerName", "new"."zoneName", "new"."ownerName", NULL);
                      END
                      """,
                      [40]: """
                      CREATE TRIGGER "sqlite_icloud_after_insert_on_tags"
                      AFTER INSERT ON "tags"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."title", 'tags', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [41]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_childWithOnDeleteSetDefaults"
                      AFTER UPDATE OF "id" ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [42]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_childWithOnDeleteSetNulls"
                      AFTER UPDATE OF "id" ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [43]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_modelAs"
                      AFTER UPDATE OF "id" ON "modelAs"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [44]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_modelBs"
                      AFTER UPDATE OF "id" ON "modelBs"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [45]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_modelCs"
                      AFTER UPDATE OF "id" ON "modelCs"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [46]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_parents"
                      AFTER UPDATE OF "id" ON "parents"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [47]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_reminderTags"
                      AFTER UPDATE OF "id" ON "reminderTags"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [48]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_reminders"
                      AFTER UPDATE OF "id" ON "reminders"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [49]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_remindersListAssets"
                      AFTER UPDATE OF "remindersListID" ON "remindersListAssets"
                      FOR EACH ROW WHEN ("old"."remindersListID") <> ("new"."remindersListID") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [50]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_remindersListPrivates"
                      AFTER UPDATE OF "remindersListID" ON "remindersListPrivates"
                      FOR EACH ROW WHEN ("old"."remindersListID") <> ("new"."remindersListID") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [51]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_remindersLists"
                      AFTER UPDATE OF "id" ON "remindersLists"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [52]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_scopedModels"
                      AFTER UPDATE OF "id" ON "scopedModels"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [53]: """
                      CREATE TRIGGER "sqlite_icloud_after_primary_key_change_on_tags"
                      AFTER UPDATE OF "title" ON "tags"
                      FOR EACH ROW WHEN ("old"."title") <> ("new"."title") BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        UPDATE "sqlite_icloud_metadata"
                        SET "_isDeleted" = 1
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("old"."title")) AND (("sqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [54]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_childWithOnDeleteSetDefaults"
                      AFTER UPDATE ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetDefaults', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."parentID", "parentRecordType" = 'parents', "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [55]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_childWithOnDeleteSetNulls"
                      AFTER UPDATE ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetNulls', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("sqlite_icloud_metadata"."recordType") = ('parents'))))), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."parentID", "parentRecordType" = 'parents', "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [56]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_modelAs"
                      AFTER UPDATE ON "modelAs"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelAs', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce("sqlite_icloud_currentZoneName"(), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("sqlite_icloud_currentOwnerName"(), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [57]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_modelBs"
                      AFTER UPDATE ON "modelBs"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelBs', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs'))))), '__defaultOwner__'), "new"."modelAID", 'modelAs'
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs'))))), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelAs'))))), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."modelAID", "parentRecordType" = 'modelAs', "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [58]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_modelCs"
                      AFTER UPDATE ON "modelCs"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelCs', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs'))))), '__defaultOwner__'), "new"."modelBID", 'modelBs'
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs'))))), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("sqlite_icloud_metadata"."recordType") = ('modelBs'))))), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."modelBID", "parentRecordType" = 'modelBs', "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [59]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_parents"
                      AFTER UPDATE ON "parents"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'parents', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce("sqlite_icloud_currentZoneName"(), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("sqlite_icloud_currentOwnerName"(), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [60]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_reminderTags"
                      AFTER UPDATE ON "reminderTags"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminderTags', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce("sqlite_icloud_currentZoneName"(), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("sqlite_icloud_currentOwnerName"(), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [61]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_reminders"
                      AFTER UPDATE ON "reminders"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminders', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."remindersListID", "parentRecordType" = 'remindersLists', "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [62]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_remindersListAssets"
                      AFTER UPDATE ON "remindersListAssets"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListAssets', coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."remindersListID", "parentRecordType" = 'remindersLists', "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [63]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_remindersListPrivates"
                      AFTER UPDATE ON "remindersListPrivates"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListPrivates', coalesce(coalesce('zone', "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce('__defaultOwner__', "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce('zone', "sqlite_icloud_currentZoneName"(), (SELECT "sqlite_icloud_metadata"."zoneName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce('__defaultOwner__', "sqlite_icloud_currentOwnerName"(), (SELECT "sqlite_icloud_metadata"."ownerName"
                        FROM "sqlite_icloud_metadata"
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."remindersListID", "parentRecordType" = 'remindersLists', "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [64]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_remindersLists"
                      AFTER UPDATE ON "remindersLists"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'remindersLists', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce("sqlite_icloud_currentZoneName"(), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("sqlite_icloud_currentOwnerName"(), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [65]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_scopedModels"
                      AFTER UPDATE ON "scopedModels"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'scopedModels', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce("sqlite_icloud_currentZoneName"(), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("sqlite_icloud_currentOwnerName"(), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("sqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [66]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_sqlite_icloud_metadata"
                      AFTER UPDATE ON "sqlite_icloud_metadata"
                      FOR EACH ROW WHEN (("old"."_isDeleted") = ("new"."_isDeleted")) AND (NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) BEGIN
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.invalid-record-name-error')
                        WHERE NOT (((substr("new"."recordName", 1, 1)) <> ('_')) AND ((octet_length("new"."recordName")) <= (255))) AND ((octet_length("new"."recordName")) = (length("new"."recordName")));
                        SELECT "sqlite_icloud_didUpdate"("new"."recordName", "new"."zoneName", "new"."ownerName", "old"."zoneName", "old"."ownerName", CASE WHEN (("new"."zoneName") <> ("old"."zoneName")) OR (("new"."ownerName") <> ("old"."ownerName")) THEN (
                          WITH "descendantMetadatas" AS (
                            SELECT "sqlite_icloud_metadata"."recordName" AS "recordName", NULL AS "parentRecordName"
                            FROM "sqlite_icloud_metadata"
                            WHERE (("sqlite_icloud_metadata"."recordName") = ("new"."recordName"))
                              UNION ALL
                            SELECT "sqlite_icloud_metadata"."recordName" AS "recordName", "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName"
                            FROM "sqlite_icloud_metadata"
                            JOIN "descendantMetadatas" ON ("sqlite_icloud_metadata"."parentRecordName") = ("descendantMetadatas"."recordName")
                          )
                          SELECT json_group_array("descendantMetadatas"."recordName")
                          FROM "descendantMetadatas"
                          WHERE (("descendantMetadatas"."recordName") <> ("new"."recordName"))
                        ) END);
                      END
                      """,
                      [67]: """
                      CREATE TRIGGER "sqlite_icloud_after_update_on_tags"
                      AFTER UPDATE ON "tags"
                      FOR EACH ROW BEGIN
                        WITH "rootShares" AS (
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("sqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "sqlite_icloud_metadata"."share" AS "share"
                          FROM "sqlite_icloud_metadata"
                          JOIN "rootShares" ON ("sqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShares"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShares"
                        WHERE (((NOT ("sqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShares"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("sqlite_icloud_hasPermission"("rootShares"."share"))));
                        INSERT INTO "sqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."title", 'tags', coalesce("sqlite_icloud_currentZoneName"(), 'zone'), coalesce("sqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = coalesce("sqlite_icloud_currentZoneName"(), "sqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("sqlite_icloud_currentOwnerName"(), "sqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = sqlite_icloud_currentTime()
                        WHERE ((("sqlite_icloud_metadata"."recordPrimaryKey") = ("new"."title")) AND (("sqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [68]: """
                      CREATE TRIGGER "sqlite_icloud_after_zone_update_on_sqlite_icloud_metadata"
                      AFTER UPDATE OF "zoneName", "ownerName" ON "sqlite_icloud_metadata"
                      FOR EACH ROW WHEN (("new"."zoneName") <> ("old"."zoneName")) OR (("new"."ownerName") <> ("old"."ownerName")) BEGIN
                        UPDATE "sqlite_icloud_metadata"
                        SET "zoneName" = "new"."zoneName", "ownerName" = "new"."ownerName", "lastKnownServerRecord" = NULL, "_lastKnownServerRecordAllFields" = NULL
                        WHERE (("sqlite_icloud_metadata"."recordName") IN (WITH "descendantMetadatas" AS (
                          SELECT "sqlite_icloud_metadata"."recordName" AS "recordName", NULL AS "parentRecordName"
                          FROM "sqlite_icloud_metadata"
                          WHERE (("sqlite_icloud_metadata"."recordName") = ("new"."recordName"))
                            UNION ALL
                          SELECT "sqlite_icloud_metadata"."recordName" AS "recordName", "sqlite_icloud_metadata"."parentRecordName" AS "parentRecordName"
                          FROM "sqlite_icloud_metadata"
                          JOIN "descendantMetadatas" ON ("sqlite_icloud_metadata"."parentRecordName") = ("descendantMetadatas"."recordName")
                        )
                        SELECT "descendantMetadatas"."recordName"
                        FROM "descendantMetadatas"));
                      END
                      """
                    ]
                    """#
                }

                try syncEngine.tearDownSyncEngine()
                let triggersAfterTearDown = try await userDatabase.userWrite { db in
                    try #sql("SELECT sql FROM sqlite_temp_master", as: String?.self).fetchAll(db)
                }
                assertInlineSnapshot(of: triggersAfterTearDown, as: .customDump) {
                    """
                    []
                    """
                }

                try syncEngine.setUpSyncEngine()
                try await syncEngine.start()
                let triggersAfterReSetUp = try await userDatabase.userWrite { db in
                    try #sql("SELECT sql FROM sqlite_temp_master ORDER BY sql", as: String?.self).fetchAll(db)
                }
                #expect(triggersAfterReSetUp == triggersAfterSetUp)
            }
        }
    }
#endif
