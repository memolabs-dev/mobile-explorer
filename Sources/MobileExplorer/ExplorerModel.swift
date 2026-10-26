import Foundation
import AppKit
import Combine

@MainActor
final class ExplorerModel: ObservableObject {
    @Published var devices: [ConnectedDevice] = []
    @Published var selectedDeviceID: ConnectedDevice.ID?
    @Published var applications: [InstalledApplication] = []
    @Published var selectedApplicationID: InstalledApplication.ID?
    @Published var observations: [Observation] = []
    @Published var notes = ""
    @Published var manualAppName = ""
    @Published var manualApplication: InstalledApplication?
    @Published var isBusy = false
    @Published var statusMessage = "Connectez un iPhone déverrouillé pour commencer."
    @Published var errorMessage: String?

    var selectedDevice: ConnectedDevice? { devices.first(where: { $0.id == selectedDeviceID }) }
    var selectedApplication: InstalledApplication? {
        if manualApplication?.id == selectedApplicationID { return manualApplication }
        return applications.first(where: { $0.id == selectedApplicationID })
    }

    func refreshDevices() {
        isBusy = true
        errorMessage = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[ConnectedDevice], Error> in
                do { return .success(try DeviceScanner().listDevices()) }
                catch { return .failure(error) }
            }.value
            isBusy = false
            switch result {
            case .success(let data):
                devices = data
                if let selectedDeviceID, !data.contains(where: { $0.id == selectedDeviceID }) {
                    self.selectedDeviceID = nil; applications = []; selectedApplicationID = nil
                    observations = []; notes = ""
                }
                statusMessage = data.isEmpty ? "Aucun iPhone trouvé. Vérifiez le câble, la confiance et Xcode." : "\(data.count) iPhone(s) détecté(s)."
            case .failure(let error):
                let keepManual = selectedApplication?.origin == "Saisie manuelle"
                devices = []; selectedDeviceID = nil; applications = []
                if !keepManual {
                    selectedApplicationID = nil; observations = []; notes = ""
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectDevice(_ id: ConnectedDevice.ID) {
        guard devices.contains(where: { $0.id == id }) else { return }
        selectedDeviceID = id
        applications = []; selectedApplicationID = nil
        observations = []; notes = ""
        errorMessage = nil
        statusMessage = "Appareil sélectionné. La lecture des apps nécessite un accès CoreDevice actif."
    }

    func scanApplications() {
        guard let device = selectedDevice else { errorMessage = ExplorerError.noDevice.localizedDescription; return }
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        applications = []; selectedApplicationID = nil
        observations = []; notes = ""
        statusMessage = "Lecture du catalogue local, sans extraction des binaires…"
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[InstalledApplication], Error> in
                do { return .success(try ApplicationScanner().listApplications(on: device)) }
                catch { return .failure(error) }
            }.value
            isBusy = false
            switch result {
            case .success(let apps):
                applications = apps
                selectedApplicationID = nil
                statusMessage = "\(apps.count) applications listées. Sélectionnez une application autorisée."
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    func selectApplication(_ id: String) {
        selectedApplicationID = id
        observations = []
        notes = ""
    }

    func createManualApp() {
        let name = manualAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty && name.count <= 120 else {
            errorMessage = "Saisissez un nom valide (120 caractères maximum)."
            return
        }
        let app = InstalledApplication(id: "manual-" + UUID().uuidString, name: name, version: "inconnue", origin: "Saisie manuelle")
        manualApplication = app
        selectedApplicationID = app.id
        observations = []; notes = ""
        errorMessage = nil
        statusMessage = "Fiche manuelle créée. Le logiciel n'a pas été inventorié par CoreDevice."
    }

    func addObservation() { observations.append(Observation()) }

    func exportJSONLines() {
        guard let app = selectedApplication else { return }
        guard !observations.isEmpty else {
            errorMessage = "Ajoutez au moins un parcours à exporter."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Exporter les observations JSON Lines"
        panel.message = "Vérifiez les notes : elles ne sont pas anonymisées automatiquement."
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "mobile-explorer-evidence.jsonl"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try AppSpecExporter.jsonLines(for: app, observations: observations, generalNotes: notes)
                try data.write(to: url, atomically: true, encoding: .utf8)
                statusMessage = "Observations JSON Lines exportées localement (non vérifiées)."
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func exportReport() {
        guard let app = selectedApplication else { return }
        let panel = NSSavePanel()
        panel.title = "Exporter une fiche d'observation"
        panel.message = "Vérifiez que vos notes ne contiennent pas de données personnelles ou de secrets."
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(app.id.replacingOccurrences(of: ".", with: "-"))-observation.md"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let result = AppSpecExporter.markdown(for: app, observations: observations, generalNotes: notes)
                try result.write(to: url, atomically: true, encoding: .utf8)
                statusMessage = "Rapport sauvegardé localement."
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
