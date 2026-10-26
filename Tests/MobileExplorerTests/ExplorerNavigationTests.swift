import Foundation
import XCTest
@testable import MobileExplorer

@MainActor
final class ExplorerNavigationTests: XCTestCase {
    private func app(_ id: String) -> InstalledApplication {
        InstalledApplication(id: id, name: id, version: "1", origin: "iPhone · CoreDevice (Xcode)")
    }

    func testSelectingSameApplicationNeverWipesWork() {
        let model = ExplorerModel()
        model.applications = [app("com.example.a")]
        model.selectApplication("com.example.a")
        model.observations = [Observation(screenName: "Accueil")]
        model.notes = "Travail en cours"
        model.selectApplication("com.example.a")
        XCTAssertEqual(model.selectedApplicationID, "com.example.a")
        XCTAssertEqual(model.observations.count, 1)
        XCTAssertEqual(model.notes, "Travail en cours")
        XCTAssertNil(model.pendingNavigation)
    }

    func testApplicationSwitchRequiresConfirmationAndCancelKeepsNotes() {
        let model = ExplorerModel()
        model.applications = [app("com.example.a"), app("com.example.b")]
        model.selectApplication("com.example.a")
        model.observations = [Observation(screenName: "Accueil")]
        model.selectApplication("com.example.b")
        XCTAssertEqual(model.pendingNavigation, .application("com.example.b"))
        XCTAssertEqual(model.selectedApplicationID, "com.example.a")
        XCTAssertEqual(model.observations.count, 1)
        model.cancelPendingNavigation()
        XCTAssertNil(model.pendingNavigation)
        XCTAssertEqual(model.observations.count, 1)
        model.selectApplication("com.example.b")
        model.discardAndContinue()
        XCTAssertEqual(model.selectedApplicationID, "com.example.b")
        XCTAssertTrue(model.observations.isEmpty)
    }

    func testCreatingNewManualAppWithWorkRequiresConfirmation() {
        let model = ExplorerModel()
        model.manualAppName = "Première"
        model.createManualApp()
        let oldId = model.selectedApplicationID
        model.notes = "Notes non sauvegardées"
        model.manualAppName = "Deuxième"
        model.createManualApp()
        XCTAssertEqual(model.pendingNavigation, .manualApp("Deuxième"))
        XCTAssertEqual(model.selectedApplicationID, oldId)
        XCTAssertEqual(model.notes, "Notes non sauvegardées")
        model.discardAndContinue()
        XCTAssertEqual(model.manualApplication?.name, "Deuxième")
        XCTAssertTrue(model.notes.isEmpty)
    }

    func testDeviceSwitchAndApplicationScanDoNotDiscardWithoutApproval() {
        let model = ExplorerModel()
        let first = ConnectedDevice(id: "one", udid: "secret-one", name: "iPhone", model: "iPhone", platform: "iOS", state: "connected", connectionHint: "ok")
        let second = ConnectedDevice(id: "two", udid: "secret-two", name: "iPhone", model: "iPhone", platform: "iOS", state: "connected", connectionHint: "ok")
        model.devices = [first, second]
        model.selectDevice("one")
        model.notes = "Notes importantes"
        model.selectDevice("two")
        XCTAssertEqual(model.pendingNavigation, .device("two"))
        XCTAssertEqual(model.selectedDeviceID, "one")
        model.cancelPendingNavigation()
        model.scanApplications()
        XCTAssertEqual(model.pendingNavigation, .applicationScan)
        XCTAssertEqual(model.notes, "Notes importantes")
        XCTAssertFalse(model.isBusy)
    }

    func testOpeningAnotherDraftPromptsInsteadOfShowingFilePanelImmediately() {
        let model = ExplorerModel()
        model.notes = "Ne pas remplacer"
        model.openManualDraft()
        XCTAssertEqual(model.pendingNavigation, .openDraft)
        XCTAssertEqual(model.notes, "Ne pas remplacer")
        model.cancelPendingNavigation()
        XCTAssertNil(model.pendingNavigation)
    }
}
