#if CloudKit
    import GRDB
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
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_childWithOnDeleteSetDefaults_from_sync_engine"
                      AFTER DELETE ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [1]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_childWithOnDeleteSetDefaults_from_user"
                      AFTER DELETE ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [2]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_childWithOnDeleteSetNulls_from_sync_engine"
                      AFTER DELETE ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [3]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_childWithOnDeleteSetNulls_from_user"
                      AFTER DELETE ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [4]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_modelAs_from_sync_engine"
                      AFTER DELETE ON "modelAs"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [5]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_modelAs_from_user"
                      AFTER DELETE ON "modelAs"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [6]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_modelBs_from_sync_engine"
                      AFTER DELETE ON "modelBs"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [7]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_modelBs_from_user"
                      AFTER DELETE ON "modelBs"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [8]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_modelCs_from_sync_engine"
                      AFTER DELETE ON "modelCs"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [9]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_modelCs_from_user"
                      AFTER DELETE ON "modelCs"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [10]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_parents_from_sync_engine"
                      AFTER DELETE ON "parents"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [11]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_parents_from_user"
                      AFTER DELETE ON "parents"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [12]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_reminderTags_from_sync_engine"
                      AFTER DELETE ON "reminderTags"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [13]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_reminderTags_from_user"
                      AFTER DELETE ON "reminderTags"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [14]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_remindersListAssets_from_sync_engine"
                      AFTER DELETE ON "remindersListAssets"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [15]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_remindersListAssets_from_user"
                      AFTER DELETE ON "remindersListAssets"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [16]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_remindersListPrivates_from_sync_engine"
                      AFTER DELETE ON "remindersListPrivates"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [17]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_remindersListPrivates_from_user"
                      AFTER DELETE ON "remindersListPrivates"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [18]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_remindersLists_from_sync_engine"
                      AFTER DELETE ON "remindersLists"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [19]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_remindersLists_from_user"
                      AFTER DELETE ON "remindersLists"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [20]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_reminders_from_sync_engine"
                      AFTER DELETE ON "reminders"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [21]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_reminders_from_user"
                      AFTER DELETE ON "reminders"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [22]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_scopedModels_from_sync_engine"
                      AFTER DELETE ON "scopedModels"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [23]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_scopedModels_from_user"
                      AFTER DELETE ON "scopedModels"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [24]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_swiftsqlite_icloud_metadata"
                      AFTER UPDATE OF "_isDeleted" ON "swiftsqlite_icloud_metadata"
                      FOR EACH ROW WHEN ((NOT ("old"."_isDeleted")) AND ("new"."_isDeleted")) AND (NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) BEGIN
                        SELECT "swiftsqlite_icloud_didDelete"("new"."recordName", coalesce("new"."lastKnownServerRecord", (
                          WITH "ancestorMetadata" AS (
                            SELECT "swiftsqlite_icloud_metadata"."recordName" AS "recordName", "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."lastKnownServerRecord" AS "lastKnownServerRecord"
                            FROM "swiftsqlite_icloud_metadata"
                            WHERE (("swiftsqlite_icloud_metadata"."recordName") = ("new"."recordName"))
                              UNION ALL
                            SELECT "swiftsqlite_icloud_metadata"."recordName" AS "recordName", "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."lastKnownServerRecord" AS "lastKnownServerRecord"
                            FROM "swiftsqlite_icloud_metadata"
                            JOIN "ancestorMetadata" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("ancestorMetadata"."parentRecordName")
                          )
                          SELECT "ancestorMetadata"."lastKnownServerRecord"
                          FROM "ancestorMetadata"
                          WHERE (("ancestorMetadata"."parentRecordName") IS NOT DISTINCT FROM (NULL))
                        )), "new"."share");
                      END
                      """,
                      [25]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_tags_from_sync_engine"
                      AFTER DELETE ON "tags"
                      FOR EACH ROW WHEN "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"() BEGIN
                        DELETE FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."title")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [26]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_delete_on_tags_from_user"
                      AFTER DELETE ON "tags"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."title")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [27]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_childWithOnDeleteSetDefaults"
                      AFTER INSERT ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetDefaults', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [28]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_childWithOnDeleteSetNulls"
                      AFTER INSERT ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetNulls', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [29]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_modelAs"
                      AFTER INSERT ON "modelAs"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelAs', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [30]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_modelBs"
                      AFTER INSERT ON "modelBs"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelBs', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs'))))), '__defaultOwner__'), "new"."modelAID", 'modelAs'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [31]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_modelCs"
                      AFTER INSERT ON "modelCs"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelCs', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs'))))), '__defaultOwner__'), "new"."modelBID", 'modelBs'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [32]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_parents"
                      AFTER INSERT ON "parents"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'parents', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [33]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_reminderTags"
                      AFTER INSERT ON "reminderTags"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminderTags', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [34]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_reminders"
                      AFTER INSERT ON "reminders"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminders', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [35]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_remindersListAssets"
                      AFTER INSERT ON "remindersListAssets"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListAssets', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [36]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_remindersListPrivates"
                      AFTER INSERT ON "remindersListPrivates"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListPrivates', coalesce(coalesce('zone', "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce('__defaultOwner__', "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [37]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_remindersLists"
                      AFTER INSERT ON "remindersLists"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'remindersLists', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [38]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_scopedModels"
                      AFTER INSERT ON "scopedModels"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'scopedModels', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [39]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_swiftsqlite_icloud_metadata"
                      AFTER INSERT ON "swiftsqlite_icloud_metadata"
                      FOR EACH ROW WHEN NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()) BEGIN
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.invalid-record-name-error')
                        WHERE NOT (((substr("new"."recordName", 1, 1)) <> ('_')) AND ((octet_length("new"."recordName")) <= (255))) AND ((octet_length("new"."recordName")) = (length("new"."recordName")));
                        SELECT "swiftsqlite_icloud_didUpdate"("new"."recordName", "new"."zoneName", "new"."ownerName", "new"."zoneName", "new"."ownerName", NULL);
                      END
                      """,
                      [40]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_insert_on_tags"
                      AFTER INSERT ON "tags"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."title", 'tags', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                      END
                      """,
                      [41]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_childWithOnDeleteSetDefaults"
                      AFTER UPDATE OF "id" ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [42]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_childWithOnDeleteSetNulls"
                      AFTER UPDATE OF "id" ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [43]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_modelAs"
                      AFTER UPDATE OF "id" ON "modelAs"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [44]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_modelBs"
                      AFTER UPDATE OF "id" ON "modelBs"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [45]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_modelCs"
                      AFTER UPDATE OF "id" ON "modelCs"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [46]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_parents"
                      AFTER UPDATE OF "id" ON "parents"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [47]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_reminderTags"
                      AFTER UPDATE OF "id" ON "reminderTags"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [48]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_reminders"
                      AFTER UPDATE OF "id" ON "reminders"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [49]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_remindersListAssets"
                      AFTER UPDATE OF "remindersListID" ON "remindersListAssets"
                      FOR EACH ROW WHEN ("old"."remindersListID") <> ("new"."remindersListID") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [50]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_remindersListPrivates"
                      AFTER UPDATE OF "remindersListID" ON "remindersListPrivates"
                      FOR EACH ROW WHEN ("old"."remindersListID") <> ("new"."remindersListID") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [51]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_remindersLists"
                      AFTER UPDATE OF "id" ON "remindersLists"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [52]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_scopedModels"
                      AFTER UPDATE OF "id" ON "scopedModels"
                      FOR EACH ROW WHEN ("old"."id") <> ("new"."id") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [53]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_primary_key_change_on_tags"
                      AFTER UPDATE OF "title" ON "tags"
                      FOR EACH ROW WHEN ("old"."title") <> ("new"."title") BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "_isDeleted" = TRUE
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("old"."title")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [54]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_childWithOnDeleteSetDefaults"
                      AFTER UPDATE ON "childWithOnDeleteSetDefaults"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetDefaults', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."parentID", "parentRecordType" = 'parents', "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetDefaults')));
                      END
                      """,
                      [55]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_childWithOnDeleteSetNulls"
                      AFTER UPDATE ON "childWithOnDeleteSetNulls"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('parents')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'childWithOnDeleteSetNulls', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), '__defaultOwner__'), "new"."parentID", 'parents'
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."parentID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents'))))), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."parentID", "parentRecordType" = 'parents', "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('childWithOnDeleteSetNulls')));
                      END
                      """,
                      [56]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_modelAs"
                      AFTER UPDATE ON "modelAs"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelAs', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce("swiftsqlite_icloud_currentZoneName"(), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("swiftsqlite_icloud_currentOwnerName"(), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs')));
                      END
                      """,
                      [57]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_modelBs"
                      AFTER UPDATE ON "modelBs"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelAs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelBs', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs'))))), '__defaultOwner__'), "new"."modelAID", 'modelAs'
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs'))))), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelAID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelAs'))))), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."modelAID", "parentRecordType" = 'modelAs', "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs')));
                      END
                      """,
                      [58]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_modelCs"
                      AFTER UPDATE ON "modelCs"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('modelBs')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'modelCs', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs'))))), '__defaultOwner__'), "new"."modelBID", 'modelBs'
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs'))))), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."modelBID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelBs'))))), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."modelBID", "parentRecordType" = 'modelBs', "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('modelCs')));
                      END
                      """,
                      [59]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_parents"
                      AFTER UPDATE ON "parents"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'parents', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce("swiftsqlite_icloud_currentZoneName"(), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("swiftsqlite_icloud_currentOwnerName"(), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('parents')));
                      END
                      """,
                      [60]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_reminderTags"
                      AFTER UPDATE ON "reminderTags"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminderTags', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce("swiftsqlite_icloud_currentZoneName"(), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("swiftsqlite_icloud_currentOwnerName"(), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminderTags')));
                      END
                      """,
                      [61]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_reminders"
                      AFTER UPDATE ON "reminders"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'reminders', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."remindersListID", "parentRecordType" = 'remindersLists', "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('reminders')));
                      END
                      """,
                      [62]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_remindersListAssets"
                      AFTER UPDATE ON "remindersListAssets"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListAssets', coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce(NULL, "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."remindersListID", "parentRecordType" = 'remindersLists', "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListAssets')));
                      END
                      """,
                      [63]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_remindersListPrivates"
                      AFTER UPDATE ON "remindersListPrivates"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM ('remindersLists')))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."remindersListID", 'remindersListPrivates', coalesce(coalesce('zone', "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), 'zone'), coalesce(coalesce('__defaultOwner__', "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), '__defaultOwner__'), "new"."remindersListID", 'remindersLists'
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce(coalesce('zone', "swiftsqlite_icloud_currentZoneName"(), (SELECT "swiftsqlite_icloud_metadata"."zoneName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce(coalesce('__defaultOwner__', "swiftsqlite_icloud_currentOwnerName"(), (SELECT "swiftsqlite_icloud_metadata"."ownerName"
                        FROM "swiftsqlite_icloud_metadata"
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists'))))), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = "new"."remindersListID", "parentRecordType" = 'remindersLists', "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."remindersListID")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersListPrivates')));
                      END
                      """,
                      [64]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_remindersLists"
                      AFTER UPDATE ON "remindersLists"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'remindersLists', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce("swiftsqlite_icloud_currentZoneName"(), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("swiftsqlite_icloud_currentOwnerName"(), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('remindersLists')));
                      END
                      """,
                      [65]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_scopedModels"
                      AFTER UPDATE ON "scopedModels"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."id", 'scopedModels', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce("swiftsqlite_icloud_currentZoneName"(), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("swiftsqlite_icloud_currentOwnerName"(), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."id")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('scopedModels')));
                      END
                      """,
                      [66]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_swiftsqlite_icloud_metadata"
                      AFTER UPDATE ON "swiftsqlite_icloud_metadata"
                      FOR EACH ROW WHEN (("old"."_isDeleted") = ("new"."_isDeleted")) AND (NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) BEGIN
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.invalid-record-name-error')
                        WHERE NOT (((substr("new"."recordName", 1, 1)) <> ('_')) AND ((octet_length("new"."recordName")) <= (255))) AND ((octet_length("new"."recordName")) = (length("new"."recordName")));
                        SELECT "swiftsqlite_icloud_didUpdate"("new"."recordName", "new"."zoneName", "new"."ownerName", "old"."zoneName", "old"."ownerName", CASE WHEN (("new"."zoneName") <> ("old"."zoneName")) OR (("new"."ownerName") <> ("old"."ownerName")) THEN (
                          WITH "descendantMetadata" AS (
                            SELECT "swiftsqlite_icloud_metadata"."recordName" AS "recordName", NULL AS "parentRecordName"
                            FROM "swiftsqlite_icloud_metadata"
                            WHERE (("swiftsqlite_icloud_metadata"."recordName") = ("new"."recordName"))
                              UNION ALL
                            SELECT "swiftsqlite_icloud_metadata"."recordName" AS "recordName", "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName"
                            FROM "swiftsqlite_icloud_metadata"
                            JOIN "descendantMetadata" ON ("swiftsqlite_icloud_metadata"."parentRecordName") = ("descendantMetadata"."recordName")
                          )
                          SELECT json_group_array("descendantMetadata"."recordName")
                          FROM "descendantMetadata"
                          WHERE (("descendantMetadata"."recordName") <> ("new"."recordName"))
                        ) END);
                      END
                      """,
                      [67]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_update_on_tags"
                      AFTER UPDATE ON "tags"
                      FOR EACH ROW BEGIN
                        WITH "rootShare" AS (
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") IS NOT DISTINCT FROM (NULL)) AND (("swiftsqlite_icloud_metadata"."recordType") IS NOT DISTINCT FROM (NULL)))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName", "swiftsqlite_icloud_metadata"."share" AS "share"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "rootShare" ON ("swiftsqlite_icloud_metadata"."recordName") IS NOT DISTINCT FROM ("rootShare"."parentRecordName")
                        )
                        SELECT RAISE(ABORT, 'org.swift-institute.SQLite.CloudKit.write-permission-error')
                        FROM "rootShare"
                        WHERE (((NOT ("swiftsqlite_icloud_syncEngineIsSynchronizingChanges"())) AND (("rootShare"."parentRecordName") IS NOT DISTINCT FROM (NULL))) AND (NOT ("swiftsqlite_icloud_hasPermission"("rootShare"."share"))));
                        INSERT INTO "swiftsqlite_icloud_metadata"
                        ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "parentRecordPrimaryKey", "parentRecordType")
                        SELECT "new"."title", 'tags', coalesce("swiftsqlite_icloud_currentZoneName"(), 'zone'), coalesce("swiftsqlite_icloud_currentOwnerName"(), '__defaultOwner__'), NULL, NULL
                        ON CONFLICT DO NOTHING;
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = coalesce("swiftsqlite_icloud_currentZoneName"(), "swiftsqlite_icloud_metadata"."zoneName"), "ownerName" = coalesce("swiftsqlite_icloud_currentOwnerName"(), "swiftsqlite_icloud_metadata"."ownerName"), "parentRecordPrimaryKey" = NULL, "parentRecordType" = NULL, "userModificationTime" = swiftsqlite_icloud_currentTime()
                        WHERE ((("swiftsqlite_icloud_metadata"."recordPrimaryKey") = ("new"."title")) AND (("swiftsqlite_icloud_metadata"."recordType") = ('tags')));
                      END
                      """,
                      [68]: """
                      CREATE TRIGGER "swiftsqlite_icloud_after_zone_update_on_swiftsqlite_icloud_metadata"
                      AFTER UPDATE OF "zoneName", "ownerName" ON "swiftsqlite_icloud_metadata"
                      FOR EACH ROW WHEN (("new"."zoneName") <> ("old"."zoneName")) OR (("new"."ownerName") <> ("old"."ownerName")) BEGIN
                        UPDATE "swiftsqlite_icloud_metadata"
                        SET "zoneName" = "new"."zoneName", "ownerName" = "new"."ownerName", "lastKnownServerRecord" = NULL, "_lastKnownServerRecordAllFields" = NULL
                        WHERE (("swiftsqlite_icloud_metadata"."recordName") IN (WITH "descendantMetadata" AS (
                          SELECT "swiftsqlite_icloud_metadata"."recordName" AS "recordName", NULL AS "parentRecordName"
                          FROM "swiftsqlite_icloud_metadata"
                          WHERE (("swiftsqlite_icloud_metadata"."recordName") = ("new"."recordName"))
                            UNION ALL
                          SELECT "swiftsqlite_icloud_metadata"."recordName" AS "recordName", "swiftsqlite_icloud_metadata"."parentRecordName" AS "parentRecordName"
                          FROM "swiftsqlite_icloud_metadata"
                          JOIN "descendantMetadata" ON ("swiftsqlite_icloud_metadata"."parentRecordName") = ("descendantMetadata"."recordName")
                        )
                        SELECT "descendantMetadata"."recordName"
                        FROM "descendantMetadata"));
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
