import Foundation

struct CommandResult {
    let stdout: Data
    let status: Int32
}

protocol CommandExecuting {
    func run(_ executable: String, arguments: [String]) throws -> CommandResult
}

struct ProcessExecutor: CommandExecuting {
    func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        // No shell, no arbitrary user-provided executable and no privilege elevation.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() }
        catch { throw ExplorerError.toolMissing(executable) }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(stdout: data, status: process.terminationStatus)
    }
}

struct DeviceScanner {
    let executor: any CommandExecuting
    init(executor: any CommandExecuting = ProcessExecutor()) { self.executor = executor }

    func listDevices() throws -> [ConnectedDevice] {
        // Apple's CoreDevice CLI writes stable machine-readable JSON to a temp file.
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-explorer-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: path) }
        let result = try executor.run("/usr/bin/xcrun", arguments: ["devicectl", "list", "devices", "--json-output", path.path])
        guard result.status == 0 else { throw ExplorerError.commandFailed("devicectl n'est pas disponible ou l'accès est refusé") }
        guard let data = try? Data(contentsOf: path) else { throw ExplorerError.invalidData("devicectl n'a pas généré de JSON") }
        return try Self.parseDevices(data)
    }

    static func parseDevices(_ data: Data) throws -> [ConnectedDevice] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let rows = result["devices"] as? [[String: Any]] else {
            throw ExplorerError.invalidData("Structure CoreDevice inattendue")
        }
        return rows.compactMap { row -> ConnectedDevice? in
            let info = row["deviceProperties"] as? [String: Any] ?? [:]
            let hw = row["hardwareProperties"] as? [String: Any] ?? [:]
            let conn = row["connectionProperties"] as? [String: Any] ?? [:]
            let platform = hw["platform"] as? String ?? ""
            let model = hw["productType"] as? String ?? "Appareil Apple"
            // Only display iPhone-class devices. An unavailable device may be listed but cannot be inspected.
            guard platform.lowercased() == "ios" || model.lowercased().hasPrefix("iphone") else { return nil }
            let udid = hw["udid"] as? String ?? row["identifier"] as? String ?? ""
            guard !udid.isEmpty else { return nil }
            return ConnectedDevice(
                id: row["identifier"] as? String ?? udid,
                udid: udid,
                name: info["name"] as? String ?? model,
                model: model,
                platform: platform.isEmpty ? "iOS" : platform,
                state: conn["tunnelState"] as? String ?? "unknown"
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

struct ApplicationScanner {
    let executor: any CommandExecuting
    init(executor: any CommandExecuting = ProcessExecutor()) { self.executor = executor }

    func listApplications(on device: ConnectedDevice) throws -> [InstalledApplication] {
        // Prefer Apple's CoreDevice interface. It lists metadata only and does not access
        // app data containers. The host/device must grant a CoreDevice usage assertion.
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-explorer-apps-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: output) }
        let result = try? executor.run("/usr/bin/xcrun", arguments: [
            "devicectl", "device", "info", "apps", "--device", device.id,
            "--include-default-apps", "--json-output", output.path
        ])
        if result?.status == 0, let data = try? Data(contentsOf: output) {
            return try Self.parseCoreDeviceApplications(data)
        }

        // On unsupported or temporarily unavailable devices, use the optional
        // libimobiledevice installation service. Never fabricate an app inventory.
        let locations = ["/opt/homebrew/bin/ideviceinstaller", "/usr/local/bin/ideviceinstaller"]
        guard let executable = locations.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ExplorerError.commandFailed("CoreDevice n'a pas pu lire les applications (iPhone verrouillé, non prêt ou accès refusé). Le repli ideviceinstaller est absent : installez-le si nécessaire, ou vérifiez Xcode, le jumelage et le mode développeur.")
        }
        let fallback = try executor.run(executable, arguments: ["-u", device.udid, "list", "--xml"])
        guard fallback.status == 0 else {
            throw ExplorerError.commandFailed("CoreDevice indisponible ; ideviceinstaller a échoué (code \(fallback.status)). Vérifiez les permissions et la compatibilité iOS.")
        }
        return try Self.parseApplications(fallback.stdout)
    }

    static func parseCoreDeviceApplications(_ data: Data) throws -> [InstalledApplication] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let entries = result["apps"] as? [[String: Any]] else {
            throw ExplorerError.invalidData("Structure JSON CoreDevice inattendue")
        }
        return entries.compactMap { record -> InstalledApplication? in
            guard let bundleId = record["bundleIdentifier"] as? String, !bundleId.isEmpty else { return nil }
            return InstalledApplication(
                id: bundleId,
                name: record["name"] as? String ?? bundleId,
                version: record["version"] as? String ?? record["bundleVersion"] as? String ?? "—",
                origin: "iPhone · CoreDevice (Xcode)"
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func parseApplications(_ data: Data) throws -> [InstalledApplication] {
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        // New and older libimobiledevice builds may use an array or a dictionary keyed by bundle id.
        let entries: [Any]
        if let array = plist as? [Any] { entries = array }
        else if let dictionary = plist as? [String: Any] { entries = Array(dictionary.values) }
        else { throw ExplorerError.invalidData("Format XML plist des applications non reconnu") }
        return entries.compactMap { item -> InstalledApplication? in
            guard let dictionary = item as? [String: Any] else { return nil }
            guard let identifier = dictionary["CFBundleIdentifier"] as? String, !identifier.isEmpty else { return nil }
            return InstalledApplication(
                id: identifier,
                name: dictionary["CFBundleDisplayName"] as? String ?? dictionary["CFBundleName"] as? String ?? identifier,
                version: dictionary["CFBundleShortVersionString"] as? String ?? "—",
                origin: "iPhone · Installation Service"
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
