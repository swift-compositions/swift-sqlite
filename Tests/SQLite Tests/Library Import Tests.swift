import Foundation
import Testing

@Suite struct `Library imports` {
    @Test func `no library target imports CustomDump`() throws {
        let sources = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources")
        let libraries = try FileManager.default.contentsOfDirectory(atPath: sources.path(percentEncoded: false))
            .filter { !$0.hasSuffix("Test Support") }
        let offending = libraries.flatMap { library in
            (FileManager.default.enumerator(atPath: sources.appending(path: library).path(percentEncoded: false))?.allObjects as? [String] ?? [])
                .filter { $0.hasSuffix(".swift") }
                .filter { file in
                    ((try? String(contentsOf: sources.appending(path: library).appending(path: file), encoding: .utf8)) ?? "")
                        .contains("import CustomDump")
                }
                .map { "\(library)/\($0)" }
        }
        #expect(!libraries.isEmpty)
        #expect(offending.isEmpty)
    }
}
