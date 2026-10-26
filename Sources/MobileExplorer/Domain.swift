import Foundation

struct ConnectedDevice: Identifiable, Hashable {
    let id: String
    let udid: String
    let name: String
    let model: String
    let platform: String
    let state: String
    let connectionHint: String

    var maskedIdentifier: String {
        guard udid.count > 8 else { return "••••" }
        return String(udid.prefix(4)) + "••••" + String(udid.suffix(4))
    }
}

struct InstalledApplication: Identifiable, Hashable {
    let id: String             // Bundle identifier
    let name: String
    let version: String
    let origin: String         // Device's installation service
}

struct Observation: Identifiable, Hashable {
    let id: UUID
    var screenName: String
    var expectedAction: String
    var observedResult: String
    var notes: String
    init(id: UUID = UUID(), screenName: String = "", expectedAction: String = "", observedResult: String = "", notes: String = "") {
        self.id = id
        self.screenName = screenName
        self.expectedAction = expectedAction
        self.observedResult = observedResult
        self.notes = notes
    }
}

enum ExplorerError: LocalizedError {
    case toolMissing(String)
    case commandFailed(String)
    case invalidData(String)
    case noDevice

    var errorDescription: String? {
        switch self {
        case .toolMissing(let name): return "Outil absent : \(name). Consultez le guide d’installation."
        case .commandFailed(let message): return "La lecture de l’appareil a échoué : \(message)"
        case .invalidData(let message): return "Données inattendues : \(message)"
        case .noDevice: return "Aucun iPhone connecté ou appairé. Déverrouillez-le et confirmez « Faire confiance »."
        }
    }
}
