#if GRDB
import Foundation
import GRDB
import RFC_4122

func temporaryDatabasePool(configuration: Configuration = Configuration()) throws -> DatabasePool {
  try FileManager.default.createDirectory(
    at: temporaryDatabaseDirectory, withIntermediateDirectories: true
  )
  return try DatabasePool(
    path: temporaryDatabaseDirectory
      .appending(path: "\(String(try RFC_4122.UUID.v4())).db")
      .path(percentEncoded: false),
    configuration: configuration
  )
}

private let temporaryDatabaseDirectory = URL.temporaryDirectory.appending(
  path: "org.swift-institute.SQLite",
  directoryHint: .isDirectory
)

#endif
