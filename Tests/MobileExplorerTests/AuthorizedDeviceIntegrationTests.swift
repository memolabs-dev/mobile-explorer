import Foundation
import XCTest
@testable import MobileExplorer

/// An explicit opt-in test: the normal CI cannot access a physical iPhone.
final class AuthorizedDeviceIntegrationTests: XCTestCase {
    func testReadOnlyPhysicalDeviceInventory() throws {
        guard let id = ProcessInfo.processInfo.environment["ME_AUTHORIZED_DEVICE_ID"], !id.isEmpty else {
            throw XCTSkip("Requires explicitly authorized physical iPhone")
        }
        let devices = try DeviceScanner().listDevices()
        let device = try XCTUnwrap(devices.first(where: { $0.id == id }))
        let apps = try ApplicationScanner().listApplications(on: device)
        XCTAssertGreaterThan(apps.count, 0)
        XCTAssertTrue(apps.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty })
        XCTAssertTrue(apps.allSatisfy { $0.origin == "iPhone · CoreDevice (Xcode)" })
        print("AUTHORIZED_IPHONE_METADATA_COUNT=\(apps.count)")
    }
}
