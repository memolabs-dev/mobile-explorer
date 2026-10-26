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
}
