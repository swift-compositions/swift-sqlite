# Upstream

swift-sqlite is a fork of [pointfreeco/sqlite-data](https://github.com/pointfreeco/sqlite-data) (MIT,
Copyright (c) 2025 Point-Free, Inc.; the notice is in `LICENSE`).

**Base: tag 1.12.0, commit `164bb5f223738af3d5da7a1b8de14e67e4d9cd5d`.**
Upstream 1.12.1 (`aa613accbe882b561f26e37a348a8f42e92cd398`) changes only the README and one visionOS
collation line; it has no CloudKit change, so the base stays 1.12.0 until a release changes
`Sources/SQLiteData/CloudKit` or `Tests/SQLiteDataTests/CloudKitTests`.

## File map

Upstream `Sources/SQLiteData/CloudKit` to `Sources/SQLite CloudKit`, same names one to one, except:

| upstream | here | note |
|---|---|---|
| `Internal/Triggers.swift` | `Internal/CloudKitTriggers.swift` | renamed |
| `DefaultSyncEngine.swift` | none | swift-dependencies key; the engine is passed explicitly |
| `Internal/DatetimeGenerator.swift` | none | replaced by an explicit time input |
| `Internal/DefaultNotificationCenter.swift` | none | replaced by an explicit input |
| none | `Internal/Foundation+Atoms.swift` | bridges Foundation `UUID`/`Date` to `RFC_4122.UUID`/`Time.Instant` |
| none | `Traits/Tagged.swift` | swift-atoms Tagged conformances (upstream has them outside `CloudKit/`) |

Tests: upstream `Tests/SQLiteDataTests/CloudKitTests` (32 files, 195 `@Test`) to
`Tests/SQLite CloudKit Tests`, with the same names.

## Substitutions

- `QueryBinding` becomes `ISO_9075.Value`; `QueryFragment` becomes `ISO_9075.Fragment`.
- `@Dependency` and `prepareDependencies` become explicit inputs (swift-dependencies, IssueReporting,
  Perception and ConcurrencyExtras are not dependencies).
- Foundation `UUID` becomes `RFC_4122.UUID`; `Date` becomes `Time.Instant`.
- StructuredQueries `@Table`, `#sql`, `Insert.onConflictDoUpdate` become the swift-sql equivalents of
  the same names; `@DatabaseFunction` and `createTemporaryTrigger` come from `Sources/SQLite`.
- SQL function prefix `sqlitedata_icloud_` becomes `swiftsqlite_icloud_`; metadatabase schema name
  `sqlitedata_icloud` becomes `sqlite_icloud`.
- Upstream `///` documentation is kept as is, including its links to upstream's DocC catalogue,
  so that upstream hunks apply.

## Taking an upstream release

1. `git diff <base>..<tag> -- Sources/SQLiteData/CloudKit Tests/SQLiteDataTests/CloudKitTests`
   in a clone of pointfreeco/sqlite-data.
2. Apply it file by file to `Sources/SQLite CloudKit` and `Tests/SQLite CloudKit Tests`, applying the
   substitutions above to every hunk.
3. Run the CloudKit suites in CI on macOS and on the iOS simulator at the exact head, and read the counts
   from the log (at least 195 CloudKit tests on each platform).
4. Move the base in this file to the new tag and commit.
