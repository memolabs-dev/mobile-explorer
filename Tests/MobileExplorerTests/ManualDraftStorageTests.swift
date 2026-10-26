import Foundation
import XCTest
@testable import MobileExplorer

final class ManualDraftStorageTests: XCTestCase {
    private func workspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mobile-draft-storage-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testSavesWithPrivatePermissionsAndReadsBack() throws {
        let dir = try workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("draft.json")
        let app = InstalledApplication(id: "manual-secret-identifier", name: "App démo", version: "inconnue", origin: "Saisie manuelle")
        let bytes = try ManualDraftCodec.encode(
            app: app, observations: [Observation(screenName: "Accueil")], notes: "Notes privées"
        )
        try ManualDraftStorage.save(bytes, to: path)
        let attrs = try FileManager.default.attributesOfItem(atPath: path.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(try ManualDraftStorage.load(from: path).steps.first?.screenName, "Accueil")
        XCTAssertFalse(String(decoding: try Data(contentsOf: path), as: UTF8.self).contains("manual-secret-identifier"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["draft.json"])
    }

    func testOverwriteRestrictsPermissionsAndReplacesAtomically() throws {
        let dir = try workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("draft.json")
        try Data("old".utf8).write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path.path)
        let app = InstalledApplication(id: "manual-test", name: "New draft", version: "inconnue", origin: "Saisie manuelle")
        try ManualDraftStorage.save(ManualDraftCodec.encode(app: app, observations: [], notes: ""), to: path)
        let attrs = try FileManager.default.attributesOfItem(atPath: path.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(try ManualDraftStorage.load(from: path).applicationName, "New draft")
    }

    func testFailedFinalizationDoesNotLeakTempOrModifyDestination() throws {
        let dir = try workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        let destination = dir.appendingPathComponent("existing-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let app = InstalledApplication(id: "manual-test", name: "Test", version: "inconnue", origin: "Saisie manuelle")
        let bytes = try ManualDraftCodec.encode(app: app, observations: [], notes: "secret")
        XCTAssertThrowsError(try ManualDraftStorage.save(bytes, to: destination))
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: dir.path)), ["existing-folder"])
    }

    func testReadIsBoundedAndRejectsHugeFile() throws {
        let dir = try workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("oversize.json")
        try Data(repeating: 0x41, count: ManualDraftCodec.maximumBytes + 2).write(to: path)
        XCTAssertThrowsError(try ManualDraftStorage.load(from: path))
    }
}
