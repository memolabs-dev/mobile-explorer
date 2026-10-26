import Foundation
import XCTest
@testable import MobileExplorer

final class SpecExporterTests: XCTestCase {
    func testExportsObservationWithLimitations() {
        let app=InstalledApplication(id:"com.example.demo",name:"Demo",version:"1.2",origin:"test")
        let notes=[Observation(screenName:"Accueil",expectedAction:"Toucher le menu",observedResult:"Liste visible",notes:"Rien à signaler")]
        let result=AppSpecExporter.markdown(for:app,observations:notes,generalNotes:"À tester hors-ligne")
        XCTAssertTrue(result.contains("com.example.demo"))
        XCTAssertTrue(result.contains("Résultat observé"))
        XCTAssertTrue(result.contains("Les parcours non visités"))
        XCTAssertFalse(result.contains("reverse déchiffré"))
    }
    func testManualAppDoesNotInventBundleIdentifierOrDeviceInventory() {
        let app = InstalledApplication(id: "manual-fake-123", name: "Test", version: "inconnue", origin: "Saisie manuelle")
        let report = AppSpecExporter.markdown(for: app, observations: [], generalNotes: "")
        XCTAssertTrue(report.contains("non renseigné"))
        XCTAssertTrue(report.contains("saisie manuelle, sans inventaire"))
        XCTAssertFalse(report.contains("manual-fake-123"))
    }

    func testJSONLinesMatchesObservationContractAndDoesNotInventDeviceData() throws {
        let app = InstalledApplication(id: "manual-example", name: "Demo autorisée", version: "inconnue", origin: "Saisie manuelle")
        let observations = [
            Observation(screenName: "Accueil", expectedAction: "Menu", observedResult: "Visible", notes: "à vérifier"),
            Observation(screenName: "Profil", expectedAction: "Entrer", observedResult: "Ouvert", notes: "")
        ]
        let output = try AppSpecExporter.jsonLines(for: app, observations: observations, generalNotes: "test manuel")
        let lines = output.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        for line in lines {
            let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            XCTAssertEqual(record["schemaVersion"] as? String, "0.1")
            XCTAssertEqual(record["claimStatus"] as? String, "unknown")
            XCTAssertNotNil(record["collectedAt"] as? String)
            XCTAssertNotNil(record["capability"] as? String)
            let subject = try XCTUnwrap(record["subject"] as? [String: Any])
            XCTAssertEqual(subject["kind"] as? String, "authorized-test-app")
            XCTAssertNil(subject["bundleId"])
            let source = try XCTUnwrap(record["source"] as? [String: Any])
            XCTAssertEqual(source["type"] as? String, "manual-observation")
            XCTAssertNotNil(source["reference"] as? String)
            XCTAssertNotNil(record["limitations"] as? [String])
        }
        XCTAssertFalse(output.contains("udid"))
        XCTAssertFalse(output.contains("verified"))
    }

    func testJSONLinesRefusesEmptyObservations() {
        let app = InstalledApplication(id: "com.example.demo", name: "Demo", version: "1", origin: "test")
        XCTAssertThrowsError(try AppSpecExporter.jsonLines(for: app, observations: [], generalNotes: ""))
    }

}
