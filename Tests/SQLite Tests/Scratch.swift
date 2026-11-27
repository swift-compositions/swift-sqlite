import Foundation
import Path

/// A place for a test's database file.
enum Scratch {
    /// A path, in a folder of its own, at which no database exists yet.
    static func path(_ name: String = "store.sqlite") throws -> Path::Path {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try Path::Path(validating: folder.appending(path: name).path(percentEncoded: false))
    }
}
