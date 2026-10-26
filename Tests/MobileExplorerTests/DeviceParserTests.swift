import Foundation
import XCTest
@testable import MobileExplorer

final class DeviceParserTests: XCTestCase {
    func testParsesOnlyIPhoneEntries() throws {
        let input = """
        {"result":{"devices":[
          {"identifier":"device-1","hardwareProperties":{"udid":"abcd1234ffff","platform":"iOS","productType":"iPhone17,5"},"deviceProperties":{"name":"Test phone"},"connectionProperties":{"tunnelState":"connected"}},
          {"identifier":"device-2","hardwareProperties":{"platform":"macOS","productType":"MacBookPro"},"deviceProperties":{"name":"Mac"}}
        ]}}
        """.data(using: .utf8)!
        let devices = try DeviceScanner.parseDevices(input)
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.name, "Test phone")
        XCTAssertFalse(devices.first!.maskedIdentifier.contains("1234ffff"))
    }

    func testParsesAppsPlist() throws {
        let list: [[String:String]] = [
            ["CFBundleIdentifier":"com.example.test","CFBundleDisplayName":"Demo App","CFBundleShortVersionString":"2.1"],
            ["CFBundleIdentifier":"com.example.two","CFBundleName":"Other"]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList:list,format:.xml,options:0)
        let apps = try ApplicationScanner.parseApplications(data)
        XCTAssertEqual(apps.count,2)
        XCTAssertEqual(apps.first?.name,"Demo App")
    }

    func testParsesCoreDeviceAppList() throws {
        let json = """
        {"result":{"apps":[
          {"bundleIdentifier":"com.example.notes","name":"Notes Demo","version":"1.2.3","defaultApp":false},
          {"bundleIdentifier":"com.example.photo","name":"Photo Demo","bundleVersion":"45"},
          {"name":"Missing identifier"}
        ]}}
        """.data(using: .utf8)!
        let apps = try ApplicationScanner.parseCoreDeviceApplications(json)
        XCTAssertEqual(apps.count, 2)
        XCTAssertEqual(apps.map(\.id), ["com.example.notes", "com.example.photo"])
        XCTAssertEqual(apps[0].version, "1.2.3")
        XCTAssertEqual(apps[1].version, "45")
    }

    func testCoreDeviceParserRejectsUnknownEnvelope() {
        let invalid = Data("{\\"result\\":{}}".utf8)
        XCTAssertThrowsError(try ApplicationScanner.parseCoreDeviceApplications(invalid))
    }
}
