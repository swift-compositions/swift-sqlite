#if CloudKit
    import GRDB
    import CloudKit
    import SQL
    import SQL_Macros
    import SQLite

    @Table
    struct RepresentableFields {
        @Column(as: _SystemFieldsRepresentation<CKShare>.self)
        var share: CKShare
        @Column(as: _SystemFieldsRepresentation<CKShare>?.self)
        var optionalShare: CKShare?
        @Column(as: _SystemFieldsRepresentation<CKRecord>.self)
        var record: CKRecord
        @Column(as: _SystemFieldsRepresentation<CKRecord>?.self)
        var optionalRecord: CKRecord?
    }

    @DatabaseFunction(
        as: ((
            _SystemFieldsRepresentation<CKShare>,
            _SystemFieldsRepresentation<CKRecord>,
            _SystemFieldsRepresentation<CKShare>?,
            _SystemFieldsRepresentation<CKRecord>?
        ) -> Void).self
    )
    nonisolated func representableArguments(
        share: CKShare,
        record: CKRecord,
        optionalShare: CKShare?,
        optionalRecord: CKRecord?
    ) {
    }
#endif
