#if GRDB
public import GRDB
public import SQL

extension SQL::Table {
  @inlinable
  public static func fetchAll(_ db: GRDB.Database) throws -> [QueryOutput] {
    try all.fetchAll(db)
  }

  @inlinable
  public static func fetchOne(_ db: GRDB.Database) throws -> QueryOutput? {
    try all.fetchOne(db)
  }

  @inlinable
  public static func fetchCount(_ db: GRDB.Database) throws -> Int {
    try all.fetchCount(db)
  }

  @inlinable
  public static func fetchCursor(_ db: GRDB.Database) throws -> QueryCursor<QueryOutput> {
    try all.fetchCursor(db)
  }
}

extension SQL::PrimaryKeyedTable {
  @inlinable
  public static func find(
    _ db: GRDB.Database,
    key primaryKey: some QueryExpression<PrimaryKey>
  ) throws -> QueryOutput {
    try all.find(db, key: primaryKey)
  }
}

#endif
