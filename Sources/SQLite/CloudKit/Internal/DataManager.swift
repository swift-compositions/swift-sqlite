#if CloudKit
#if canImport(CloudKit) && canImport(CryptoKit)
  import CryptoKit
  public import Foundation
  package import Synchronization

  public protocol DataManager: Sendable {
    func load(_ url: URL) throws -> Data
    func save(_ data: Data, to url: URL) throws
    func sha256(of fileURL: URL) -> Data?
    var temporaryDirectory: URL { get }
  }

  public struct LiveDataManager: DataManager {
    public init() {}
    public func load(_ url: URL) throws -> Data {
      try Data(contentsOf: url)
    }
    public func save(_ data: Data, to url: URL) throws {
      try data.write(to: url)
    }
    public func sha256(of fileURL: URL) -> Data? {
      do {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }
        var hasher = SHA256()
        while true {
          let finished = try autoreleasepool {
            guard
              let data = try fileHandle.read(upToCount: 1024 * 1024),
              !data.isEmpty
            else { return true }
            hasher.update(data: data)
            return false
          }
          guard !finished
          else { break }
        }
        let digest = hasher.finalize()
        return Data(digest)
      } catch {
        return nil
      }
    }
    public var temporaryDirectory: URL {
      URL(fileURLWithPath: NSTemporaryDirectory())
    }
  }

  public final class InMemoryDataManager: DataManager {
    package let storage = Mutex<[URL: Data]>([:])

    public init() {}

    public func load(_ url: URL) throws -> Data {
      try storage.withLock { storage throws -> Data in
        guard let data = storage[url]
        else {
          struct FileNotFound: Error {}
          throw FileNotFound()
        }
        return data
      }
    }

    public func save(_ data: Data, to url: URL) throws {
      storage.withLock { $0[url] = data }
    }

    public func sha256(of fileURL: URL) -> Data? {
      storage.withLock {
        $0[fileURL].map {
          Data(SHA256.hash(data: $0))
        }
      }
    }

    public var temporaryDirectory: URL {
      URL(fileURLWithPath: "/tmp")
    }
  }
#endif

#endif
