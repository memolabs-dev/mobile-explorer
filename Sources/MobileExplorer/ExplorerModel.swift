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

    enum PendingNavigation: Equatable {
        case application(String)
        case device(String)
        case manualApp(String)
        case applicationScan
        case openDraft
    }

    @Published var pendingNavigation: PendingNavigation?

    var hasEnteredObservations: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !observations.isEmpty
    }

    private func request(_ action: PendingNavigation) {
        if hasEnteredObservations {
            pendingNavigation = action
        } else {
            perform(action)
        }
    }

    func cancelPendingNavigation() {
        pendingNavigation = nil
    }

    func discardAndContinue() {
        guard let action = pendingNavigation else { return }
        pendingNavigation = nil
        perform(action)
    }

    private func perform(_ action: PendingNavigation) {
        switch action {
        case .application(let id):
            selectedApplicationID = id
            observations = []
            notes = ""
        case .device(let id):
            selectedDeviceID = id
            applications = []
            selectedApplicationID = nil
            observations = []
            notes = ""
            errorMessage = nil
            statusMessage = "Appareil sélectionné. La lecture des apps nécessite un accès CoreDevice actif."
        case .manualApp(let name):
            let app = InstalledApplication(id: "manual-" + UUID().uuidString, name: name, version: "inconnue", origin: "Saisie manuelle")
            manualApplication = app
            selectedApplicationID = app.id
            observations = []
            notes = ""
            errorMessage = nil
            statusMessage = "Fiche manuelle créée. Le logiciel n'a pas été inventorié par CoreDevice."
        case .applicationScan:
            startApplicationScan()
        case .openDraft:
            presentOpenDraftPanel()
        }
    }

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
                let disconnected = selectedDeviceID != nil && !data.contains(where: { $0.id == selectedDeviceID })
                if disconnected {
                    self.selectedDeviceID = nil
                    if !hasEnteredObservations && selectedApplication?.origin != "Saisie manuelle" {
                        applications = []; selectedApplicationID = nil
                        observations = []; notes = ""
                    }
                }
                statusMessage = disconnected && hasEnteredObservations
                    ? "iPhone déconnecté : les observations restent éditables et exportables."
                    : (data.isEmpty ? "Aucun iPhone trouvé. Vérifiez le câble, la confiance et Xcode." : "\(data.count) iPhone(s) détecté(s).")
            case .failure(let error):
                let keepNotes = hasEnteredObservations || selectedApplication?.origin == "Saisie manuelle"
                devices = []; selectedDeviceID = nil
                if !keepNotes {
                    applications = []; selectedApplicationID = nil; observations = []; notes = ""
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectDevice(_ id: ConnectedDevice.ID) {
        guard devices.contains(where: { $0.id == id }), selectedDeviceID != id else { return }
        request(.device(id))
    }

    func scanApplications() {
        guard selectedDevice != nil else {
            errorMessage = ExplorerError.noDevice.localizedDescription
            return
        }
        guard !isBusy else { return }
        request(.applicationScan)
    }

    private func startApplicationScan() {
        guard let device = selectedDevice, !isBusy else { return }
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
        guard selectedApplicationID != id else { return }
        guard manualApplication?.id == id || applications.contains(where: { $0.id == id }) else { return }
        request(.application(id))
    }

    func createManualApp() {
        let name = manualAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty && name.count <= 120 else {
            errorMessage = "Saisissez un nom valide (120 caractères maximum)."
            return
        }
        request(.manualApp(name))
    }

    func addObservation() { observations.append(Observation()) }

    func saveManualDraft() {
        guard let app = selectedApplication, app.origin == "Saisie manuelle" else {
            errorMessage = "Sélectionnez une fiche manuelle pour sauvegarder un brouillon."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Sauvegarder un brouillon local"
        panel.message = "Brouillon JSON non chiffré : choisissez un dossier privé, sans notes sensibles."
        panel.nameFieldStringValue = "mobile-explorer-draft.json"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try ManualDraftCodec.encode(app: app, observations: observations, notes: notes)
                try ManualDraftStorage.save(data, to: url)
                statusMessage = "Brouillon enregistré localement. Gardez ce fichier privé."
                errorMessage = nil
            } catch {
                errorMessage = "Sauvegarde non confirmée : \(error.localizedDescription)"
            }
        }
    }

    func openManualDraft() {
        guard !isBusy else { return }
        request(.openDraft)
    }

    private func presentOpenDraftPanel() {
        let panel = NSOpenPanel()
        panel.title = "Reprendre un brouillon local"
        panel.message = "Choisissez un brouillon créé par Mobile Explorer. Il remplacera la fiche en cours."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let draft = try ManualDraftStorage.load(from: url)
                let restored = InstalledApplication(id: "manual-" + UUID().uuidString, name: draft.applicationName, version: "inconnue", origin: "Saisie manuelle")
                manualAppName = draft.applicationName
                manualApplication = restored
                selectedApplicationID = restored.id
                observations = ManualDraftCodec.restoredObservations(draft)
                notes = draft.generalNotes
                errorMessage = nil
                statusMessage = "Brouillon repris localement : observations manuelles non vérifiées."
            } catch {
                errorMessage = "Brouillon non chargé : \(error.localizedDescription)"
            }
        }
    }

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
                try ManualDraftStorage.save(Data(data.utf8), to: url, maximumBytes: 8_388_608)
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
                try ManualDraftStorage.save(Data(result.utf8), to: url, maximumBytes: 8_388_608)
                statusMessage = "Rapport sauvegardé localement."
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
