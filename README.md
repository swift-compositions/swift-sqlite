# swift-sqlite

Fork of [pointfreeco/sqlite-data](https://github.com/pointfreeco/sqlite-data) 1.12.0, built on
[swift-sql](https://github.com/swift-compositions/swift-sql) (a fork of swift-structured-queries)
and GRDB.

## Products

- `SQLite`: connections, execution, decoding, observed fetches and Tagged conformances over GRDB.
- `SQLite CloudKit`: the CloudKit synchronization engine, a file-for-file port of upstream's
  `Sources/SQLiteData/CloudKit`. See [UPSTREAM.md](UPSTREAM.md) for the base revision, the file map,
  the substitutions and how to take upstream changes.
- `SQLite Test Support`: fixtures for tests.

Each part sits behind a package trait: `GRDB`, `Observation`, `CloudKit` and `Tagged`. No trait is a
default; consumers request the ones they use.

## License

MIT, Copyright (c) 2025 Point-Free, Inc. The notice is kept in [LICENSE](LICENSE), as the license
requires for copies of upstream code. Changes made in this fork are listed in [UPSTREAM.md](UPSTREAM.md).
