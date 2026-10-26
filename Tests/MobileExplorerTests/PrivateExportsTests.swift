import Foundation
import XCTest
@testable import MobileExplorer

final class PrivateExportsTests: XCTestCase {
    func testMarkdownAndJSONLAreWrittenPrivately() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-private-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = InstalledApplication(id: "manual-identifier", name: "Démo", version: "inconnue", origin: "Saisie manuelle")
        let observations = [Observation(screenName: "Accueil", expectedAction: "Ouvrir menu", observedResult: "Menu affiché", notes: "Note privée")]
        let files: [(String, Data)] = [
            ("test.md", Data(AppSpecExporter.markdown(for: app, observations: observations, generalNotes: "").utf8)),
            ("test.jsonl", Data(try AppSpecExporter.jsonLines(for: app, observations: observations, generalNotes: "").utf8))
        ]
        for (name, data) in files {
            let url = directory.appendingPathComponent(name)
            try ManualDraftStorage.save(data, to: url, maximumBytes: 8_388_608)
            XCTAssertEqual(try Data(contentsOf: url), data)
            let info = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertEqual((info[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)), Set(["test.md", "test.jsonl"]))
    }

    func testExportReplacesInsecureFileWithPrivatePermissions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-private-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("test.jsonl")
        try Data("old".utf8).write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: target.path)
        try ManualDraftStorage.save(Data("new".utf8), to: target, maximumBytes: 8_388_608)
        XCTAssertEqual(try Data(contentsOf: target), Data("new".utf8))
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testOversizedExportRefusedBeforeFileCreation() throws {
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-refused-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: target) }
        XCTAssertThrowsError(try ManualDraftStorage.save(Data(repeating: 65, count: 12), to: target, maximumBytes: 11))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
}
