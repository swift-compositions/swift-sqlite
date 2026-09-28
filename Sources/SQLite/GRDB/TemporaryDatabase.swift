#if GRDB
import Foundation
import GRDB
public import RFC_4122

func temporaryDatabasePool(
  configuration: Configuration = Configuration(),
  uuid: @escaping @Sendable () -> RFC_4122.UUID = systemRandomUUID
) throws -> DatabasePool {
  try FileManager.default.createDirectory(
    at: temporaryDatabaseDirectory, withIntermediateDirectories: true
  )
  return try DatabasePool(
    path: temporaryDatabaseDirectory
      .appending(path: "\(String(uuid())).db")
      .path(percentEncoded: false),
    configuration: configuration
  )
}

@usableFromInline
func systemRandomUUID() -> RFC_4122.UUID {
  RFC_4122.UUID.v4 { buffer in
    var generator = SystemRandomNumberGenerator()
    for index in buffer.indices {
      unsafe buffer[index] = generator.next()
    }
  }
}

private let temporaryDatabaseDirectory = URL.temporaryDirectory.appending(
  path: "org.swift-institute.SQLite",
  directoryHint: .isDirectory
)

#endif
