import Foundation
import XCTest
@testable import MobileExplorer

@MainActor
final class ExplorerDraftRoundTripTests: XCTestCase {
    private func tempFolder() throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(
            "mobile-explorer-roundtrip-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    func testModelToPrivateDiskToFreshModelRestoresCompleteWork() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("manual.json")
        let first = ExplorerModel()
        first.manualAppName = "Démonstration autorisée"
        first.createManualApp()
        first.notes = "Notes sans données personnelles"
        first.observations = [
            Observation(screenName: "Accueil", expectedAction: "Ouvrir menu", observedResult: "Menu visible", notes: "Test manuel"),
            Observation(screenName: "Paramètres", expectedAction: "Retour", observedResult: "Accueil visible", notes: "")
        ]
        try first.persistManualDraft(to: file)
        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let fresh = ExplorerModel()
        try fresh.restoreManualDraft(from: file)
        XCTAssertEqual(fresh.selectedApplication?.name, "Démonstration autorisée")
        XCTAssertEqual(fresh.selectedApplication?.origin, "Saisie manuelle")
        XCTAssertEqual(fresh.notes, "Notes sans données personnelles")
        XCTAssertEqual(fresh.observations.count, 2)
        XCTAssertEqual(fresh.observations.first?.screenName, "Accueil")
        XCTAssertEqual(fresh.observations.first?.expectedAction, "Ouvrir menu")
        XCTAssertEqual(fresh.observations.first?.observedResult, "Menu visible")
        XCTAssertEqual(fresh.observations.first?.notes, "Test manuel")
        XCTAssertEqual(fresh.observations.last?.screenName, "Paramètres")
        XCTAssertNil(fresh.selectedDeviceID)
        let exported = try AppSpecExporter.jsonLines(
            for: XCTUnwrap(fresh.selectedApplication),
            observations: fresh.observations,
            generalNotes: fresh.notes
        )
        XCTAssertEqual(exported.split(separator: "\n").count, 2)
    }

    func testInvalidFileNeverErasesCurrentManualObservations() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("invalid.json")
        try Data("{invalid".utf8).write(to: file)
        let model = ExplorerModel()
        model.manualAppName = "Fiche existante"
        model.createManualApp()
        let originalId = model.selectedApplicationID
        model.notes = "À préserver"
        model.observations = [Observation(screenName: "Écran important")]
        XCTAssertThrowsError(try model.restoreManualDraft(from: file))
        XCTAssertEqual(model.selectedApplicationID, originalId)
        XCTAssertEqual(model.manualApplication?.name, "Fiche existante")
        XCTAssertEqual(model.notes, "À préserver")
        XCTAssertEqual(model.observations.first?.screenName, "Écran important")
    }

    func testNonManualInventoryCannotBeSavedAsEditableDraft() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("forbidden.json")
        let model = ExplorerModel()
        let app = InstalledApplication(id: "com.example.demo", name: "Application", version: "1", origin: "iPhone · CoreDevice (Xcode)")
        model.applications = [app]
        model.selectApplication(app.id)
        model.notes = "Do not silently persist app inventory"
        XCTAssertThrowsError(try model.persistManualDraft(to: file))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testRestoredWorkRemainsGuardedAgainstDestructiveNavigation() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("draft.json")
        let creator = ExplorerModel()
        creator.manualAppName = "Première fiche"
        creator.createManualApp()
        creator.notes = "Important"
        try creator.persistManualDraft(to: file)
        let fresh = ExplorerModel()
        try fresh.restoreManualDraft(from: file)
        fresh.manualAppName = "Autre fiche"
        fresh.createManualApp()
        XCTAssertEqual(fresh.pendingNavigation, .manualApp("Autre fiche"))
        fresh.cancelPendingNavigation()
        XCTAssertEqual(fresh.notes, "Important")
        XCTAssertEqual(fresh.selectedApplication?.name, "Première fiche")
    }
}
