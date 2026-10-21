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

## Deviations in tests

- `Testing/TestCloud.swift` (not upstream, `@_spi(Testing)`): one mock container that several engines share, as the
  devices on one account share a container, with `SyncEngine.init(for:tables:privateTables:cloud:…)`,
  `receiveAccountChange(_:)` and `receiveZoneDeletion(_:reason:)`, so that a client can test convergence between
  devices. Upstream's tests give each engine a container of its own.
- `MockCloudDatabase` keeps every deletion with the change tag it was made at, and `MockSyncEngine.fetchChanges`
  delivers each one to every engine whose last fetch came before it; upstream forgets a deletion after its first fetch,
  so a second device never learned of it. `MockSyncEngine` sends at most 199 changes per batch and keeps sending while a
  batch was cut at that limit, as CKSyncEngine does; upstream sends one batch, which the mock database refuses above 199.
  Below 200 changes, both behave as upstream (`Test Cloud Tests.swift` covers the difference).

- `App Lifecycle Tests`: the two background-notification tests wait until the pending changes are sent
  (up to 120 s) instead of sleeping one second; on the iOS simulator under parallel load the Task that
  upstream's one-second sleep waits for does not run in time. Everything else is as upstream.

## Observation (`Sources/SQLite/Observation`, trait `Observation`)

Compared against `pointfreeco/sqlite-data` at `6390b5c076764c74713a3fd4ebcc3b61b2220dda` (14 Sep 2026), the
same `Fetch*` sources as the base.

| swift-sqlite | sqlite-data | Difference |
|---|---|---|
| `FetchKeyRequest` | `Sources/SQLiteData/FetchKeyRequest.swift` `FetchKeyRequest` | Same shape. |
| `Fetch`, `FetchAll`, `FetchOne` | `Fetch.swift`, `FetchAll.swift`, `FetchOne.swift` | The value lives in a main-actor `@Observable` `FetchStore` (the projected value), not in swift-sharing's `SharedReader`. |
| `FetchStore.load(_:database:scheduling:) async throws -> FetchSubscription` | `Fetch.load(_:database:) async throws -> FetchSubscription` and `load(_:database:scheduler:)` | Returns once the first value is in, or throws its error; keeps following until cancelled, as upstream. `database:` is required until a default database exists (below). The scheduler parameter is spelled `scheduling:`, as everywhere in swift-sqlite. |
| `FetchStore.load(_:database:animation:)` | `Fetch.load(_:database:animation:)` | Same; built on `.animation(_:)`. |
| `FetchStore.load(_:database:scheduling:)` for statements and sectioned statements (`FetchAll.swift`) | `FetchAll.load(_:database:)` and its `sectionBy` overloads | Same, awaitable. |
| `FetchSubscription` (`task`, `cancel()`) | `FetchSubscription.swift` | Same API. Uses `Synchronization.Mutex` instead of ConcurrencyExtras' `LockIsolated`, and an unfinished `AsyncStream` instead of `Task.never()`; cancelling ends the store's observation (`FetchStore.cancel()`), keeping its last value, where upstream swaps the reader for a constant one. |
| `ResultsSectionCollection`, `SectionBuilder`, `Sectioning` | `ResultsSectionCollection.swift`, `FetchAll+Sections.swift` | Same. |
| `AnimatedScheduler`, `.animation(_:)` | `Internal/FetchKey+SwiftUI.swift` `AnimatedScheduler` | Same idea; ours is public. |
| `FetchStore.Immediate` | GRDB's `.immediate` | Checks the main actor instead of the main thread (Linux). |

## Not yet ported

| sqlite-data | Why not yet |
|---|---|
| One observation per identical request, shared by every reader (`Fetch.sharedReader`, `Internal/FetchKey.swift` keyed by request, database and scheduler) | Planned after the default database. |
| `defaultDatabase(path:configuration:)` and `@Dependency(\.defaultDatabase)` (`StructuredQueries+GRDB/DefaultDatabase.swift`) | Upstream reads it through `@Dependency`; by the substitutions above swift-sqlite keeps `database:` as the explicit input. The key is ported as is into swift-interface-composable-architecture (`Interface ComposableArchitecture SQLite`, `151ba05`), which already depends on swift-dependencies; it moves here behind a trait with coenttb/work#115. |
| `Fetch.publisher` (Combine) | Not needed by any consumer. |
