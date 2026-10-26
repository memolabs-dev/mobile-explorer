import Foundation
import XCTest
@testable import MobileExplorer

final class ManualDraftCodecTests: XCTestCase {
    func testManualDraftCanBeSavedAndRestoredWithoutDeviceIdentifiers() throws {
        let app = InstalledApplication(id: "manual-secret-session-id", name: "Application autorisée", version: "inconnue", origin: "Saisie manuelle")
        let steps = [Observation(screenName: "Accueil", expectedAction: "Ouvrir menu", observedResult: "Menu visible", notes: "Capture non incluse")]
        let data = try ManualDraftCodec.encode(app: app, observations: steps, notes: "Notes locales")
        let draft = try ManualDraftCodec.decode(data)
        XCTAssertEqual(draft.applicationName, app.name)
        XCTAssertEqual(draft.generalNotes, "Notes locales")
        XCTAssertEqual(draft.steps.count, 1)
        XCTAssertEqual(ManualDraftCodec.restoredObservations(draft).first?.screenName, "Accueil")
        let content = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(content.contains("manual-secret-session-id"))
        XCTAssertFalse(content.contains("bundleId"))
        XCTAssertFalse(content.contains("udid"))
    }

    func testRejectsUnsupportedVersionAndEmptyName() throws {
        let invalidVersion = Data(#"{"schemaVersion":"99","applicationName":"Demo","generalNotes":"","steps":[]}"#.utf8)
        XCTAssertThrowsError(try ManualDraftCodec.decode(invalidVersion))
        let emptyName = Data(#"{"schemaVersion":"1","applicationName":"  ","generalNotes":"","steps":[]}"#.utf8)
        XCTAssertThrowsError(try ManualDraftCodec.decode(emptyName))
    }

    func testRejectsOversizeDraftAndTooManySteps() throws {
        XCTAssertThrowsError(try ManualDraftCodec.decode(Data(repeating: 65, count: ManualDraftCodec.maximumBytes + 1)))
        let app = InstalledApplication(id: "manual-1", name: "Demo", version: "inconnue", origin: "Saisie manuelle")
        let observations = Array(repeating: Observation(screenName: "Écran"), count: 101)
        XCTAssertThrowsError(try ManualDraftCodec.encode(app: app, observations: observations, notes: ""))
    }

    func testRejectsSavingDeviceInventoryAsManualDraft() {
        let app = InstalledApplication(id: "com.example.demo", name: "Demo", version: "1", origin: "iPhone · CoreDevice (Xcode)")
        XCTAssertThrowsError(try ManualDraftCodec.encode(app: app, observations: [], notes: ""))
    }

    func testDraftRejectsInvalidOrMalformedJSON() {
        XCTAssertThrowsError(try ManualDraftCodec.decode(Data("not json".utf8)))
    }
}
