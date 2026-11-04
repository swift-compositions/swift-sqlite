# swift-sqlite

Use this package when your app keeps its data in an SQLite file and you want to read, write and observe it with typed statements, without importing the driver underneath. Start from `SQLite.Database`; for values that follow the database into SwiftUI or other observers, use `FetchAll`, `FetchOne` or `FetchStore`. To keep the rows of that database in sync with iCloud through CloudKit, add the `SQLite CloudKit` product and start from `SyncEngine`. For PostgreSQL, use swift-postgresql instead.

## Laws

- `SQLite.Database.observe(_:)` returns once the current answer is in, which is its first element. After that it yields a new answer after each commit that changes it, in commit order. A commit that leaves the answer equal yields nothing, and a failing first read is thrown by `SQLite.Database.observe(_:)` itself.
- A `FetchStore` on the default scheduler holds its value as soon as it exists. A failing fetch keeps the last value and records the error. A cancelled store stops following writes.
- A sectioned `FetchAll` orders rows by the section first, ascending unless you give an ordering term, so a nil section comes first. Rows within a section keep the statement's own order. An unsectioned fetch is one section named nil.
- Prepared statements are cached per connection and rebound on each use, and they survive a schema change. A cursor gets its own statement, so other fetches on the same connection while it is open don't disturb it.
- Custom functions and collations belong to one connection. Add them in `SQLite.Configuration.prepareDatabase(_:)` to have them on every connection. Once removed, a statement that uses one throws.
- An aggregate `@DatabaseFunction` sees every row, in the given order when you pass `order:`.
- `CanonicalCollation` orders strings as Swift `String` comparison does, and treats canonically equivalent strings as equal.
- `Time.Instant` columns are text and keep fractional seconds through insert and update. Text that GRDB wrote for a `Date` decodes as a `Time.Instant`.
- `RFC_4122.UUID` decodes from text in any letter case. Text containing NUL binds and decodes whole.
- Inserting no rows and updating no columns run as no-ops.
- An offset without a limit renders as `LIMIT -1`. Pragma writes render their values inline, with booleans as 1 and 0, not as bindings.
- When nothing is wired, `Dependency.Values.defaultDatabase` is an in-memory database.
- `SyncEngine` checks the schema when it is created and throws if a synchronized table has `:` in its name, a foreign key to a table it doesn't synchronize, a UNIQUE constraint other than the primary key, or a foreign key cycle, including a table that references itself. A table with exactly one foreign key must use `ON DELETE CASCADE`, `SET NULL` or `SET DEFAULT`.
- Each row is one CloudKit record named `<primary key>:<table name>`, whose type is the table name. A local write fails with the message `SyncEngine.invalidRecordNameError` when that name starts with `_`, is longer than 255 bytes, or is not ASCII.
- A row of a table with exactly one foreign key is sent with the referenced row as its CloudKit parent and lives in the parent's zone. With two or more foreign keys a row has no parent. Moving a child to a parent in another zone moves the child and all its descendants.
- Merging is per field. Each field carries its own modification time, so when two devices edit different fields of one row, both edits survive.
- Fetched records that lack this package's modification time are ignored, so records written by other clients never reach the database.
- A record that arrives before its parent row is held and inserted once the parent arrives, even after a relaunch.
- When another device deleted the parent a local child was moved to, the child follows its foreign key's `ON DELETE` action. When a local delete of a parent races a remote insert of a child into it, the parent is restored.
- Fields the local schema doesn't know are kept on the server record and sent back, so an older device never erases a newer column. After a migration adds a column, rows are filled from the last known server records: a field the record lacks takes the column default, and a field cleared to nil stays NULL.
- Rows hidden by a table's default scope still synchronize in both directions.
- Writes made while the engine is stopped or not yet started are recorded and sent once it starts, deletes included.
- A blob column is uploaded as a CloudKit asset named by the hash of its bytes, so changed bytes are uploaded again.
- Only a row with no foreign key, of a table that is synchronized and not private, can be shared, and only once the engine is running and the row has been sent. Sharing the same row twice reuses its one share. Rows of private tables never enter a share and stay in the private database.
- In a read-only share, local inserts, updates and deletes fail with the message `SyncEngine.writePermissionError` and roll back. If CloudKit refuses a write the local share allowed, the write is reverted when the send fails.
- Deleting the root of a share you own deletes the share and its records. Deleting the root of a share someone else owns only leaves the share: local rows go and the owner's records stay.
- On sign out, the engine deletes every synchronized row locally, server untouched, unless a `SyncEngineDelegate` implements the account change hook. Unsynchronized tables are kept.
- A remote deletion of the engine's zone deletes all synchronized rows locally. A zone deletion caused by an encrypted data reset keeps the rows and uploads them again.
- An in-memory user database is rejected in the live context. In the test and preview contexts each one gets its own metadatabase. In the preview context, changes sync about a second after each write.
- `SyncEngine.migratePrimaryKeys(_:tables:dropUniqueConstraints:uuid:randomUUID:)` turns integer primary keys, and tables without one, into UUID text keys. An integer key and every integer foreign key to it map to the same UUID, so references survive, and rowids, constraints, indexes and triggers are kept. UNIQUE constraints stay unless `dropUniqueConstraints` is true, and a table that keeps one can't be synchronized. Text, compound and UUID keys are refused and the table left as it was.
