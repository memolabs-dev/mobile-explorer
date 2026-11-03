import SwiftUI

// Native macOS navigation, typography and system materials. The neutral content
// area is intentionally separate from the sidebar / toolbar control layer.
struct ContentView: View {
    @StateObject private var model = ExplorerModel()

    var body: some View {
        NavigationSplitView {
            ExplorerSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 245, ideal: 280, max: 360)
        } detail: {
            ExplorerDetail(model: model)
        }
        .navigationTitle("Mobile Explorer")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.refreshDevices()
                } label: {
                    Label("Actualiser les appareils", systemImage: "arrow.clockwise")
                }
                .help("Rechercher les iPhone connectés")

                Button {
                    model.openManualDraft()
                } label: {
                    Label("Ouvrir un brouillon", systemImage: "folder")
                }
                .help("Ouvrir un fichier local")
            }
        }
        .frame(minWidth: 820, minHeight: 580)
        .onAppear { model.refreshDevices() }
        .confirmationDialog(
            "Remplacer les observations en cours ?",
            isPresented: Binding(
                get: { model.pendingNavigation != nil },
                set: { if !$0 { model.cancelPendingNavigation() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Abandonner les observations", role: .destructive) {
                model.discardAndContinue()
            }
            Button("Annuler", role: .cancel) {
                model.cancelPendingNavigation()
            }
        } message: {
            Text("Sauvegardez ou exportez les notes actuelles avant de changer de fiche.")
        }
    }
}

private struct ExplorerSidebar: View {
    @ObservedObject var model: ExplorerModel

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Appareils") {
                    if model.devices.isEmpty {
                        Label("Aucun iPhone connecté", systemImage: "iphone.slash")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .accessibilityIdentifier("device.empty")
                    } else {
                        ForEach(model.devices) { device in
                            Button {
                                model.selectDevice(device.id)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "iphone.gen3")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name).lineLimit(1)
                                        Text(device.connectionHint)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                model.selectedDeviceID == device.id
                                    ? Color.accentColor.opacity(0.12) : Color.clear
                            )
                        }
                    }

                    Button {
                        model.scanApplications()
                    } label: {
                        Label("Lire les applications", systemImage: "square.grid.2x2")
                    }
                    .disabled(model.selectedDevice == nil || model.isBusy)
                    .accessibilityIdentifier("device.read-apps")
                }

                Section("Applications (\(model.applications.count))") {
                    ForEach(model.applications) { app in
                        Button {
                            model.selectApplication(app.id)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "app")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name).lineLimit(1)
                                    Text(app.id)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            model.selectedApplicationID == app.id
                                ? Color.accentColor.opacity(0.12) : Color.clear
                        )
                    }
                }

                Section("Fiches manuelles") {
                    if let manual = model.manualApplication {
                        Button {
                            model.selectApplication(manual.id)
                        } label: {
                            Label(manual.name, systemImage: "doc.text")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            model.selectedApplicationID == manual.id
                                ? Color.accentColor.opacity(0.12) : Color.clear
                        )
                    }

                    Button {
                        model.openManualDraft()
                    } label: {
                        Label("Reprendre un brouillon", systemImage: "folder")
                    }
                    .accessibilityIdentifier("draft.open")
                    .help("Ouvrir un fichier JSON local")
                }
            }
            .listStyle(.sidebar)

            Divider()
            VStack(alignment: .leading, spacing: 9) {
                Text("Nouvelle fiche")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                TextField("Nom de l’application", text: $model.manualAppName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("manual.app-name")
                Button {
                    model.createManualApp()
                } label: {
                    Label("Créer une fiche", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(model.manualAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("manual.create")
            }
            .padding(14)
            Divider()
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                Text("Données conservées sur ce Mac")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
    }
}

private struct ExplorerDetail: View {
    @ObservedObject var model: ExplorerModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    if let app = model.selectedApplication {
                        ObservationWorkspace(model: model, app: app)
                    } else {
                        ExplorerWelcomeView()
                    }
                }
                .frame(maxWidth: 880, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 30)
                .padding(.vertical, 30)
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider()
            HStack(spacing: 8) {
                if model.isBusy { ProgressView().controlSize(.small) }
                if model.errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.secondary)
                }
                Text(model.errorMessage ?? model.statusMessage)
                    .lineLimit(2)
                Spacer(minLength: 10)
                Text("Local")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

private struct ExplorerWelcomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Bienvenue dans Mobile Explorer")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Documentez le fonctionnement d’une application autorisée depuis votre Mac.")
                    .foregroundStyle(.secondary)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("Connectez et autorisez votre iPhone pour afficher les applications.", systemImage: "cable.connector")
                Label("Ou créez une fiche manuelle dans la barre latérale.", systemImage: "square.and.pencil")
                Label("Consignez les écrans et exportez vos observations localement.", systemImage: "doc.text")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 6)

            Divider().frame(maxWidth: 540)
            Text("L’application consulte des métadonnées accessibles par CoreDevice. Elle ne lit pas les données privées des applications et ne navigue pas automatiquement dans leurs interfaces.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 50)
    }
}

private struct ObservationWorkspace: View {
    @ObservedObject var model: ExplorerModel
    let app: InstalledApplication

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("FICHE D'OBSERVATION")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text(app.name)
                        .font(.title)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                    HStack(spacing: 8) {
                        Label(app.origin == "Saisie manuelle" ? "Observation manuelle" : "Inventaire iPhone",
                              systemImage: app.origin == "Saisie manuelle" ? "square.and.pencil" : "iphone")
                        Text("·")
                        Text("Non vérifiée")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(app.id + " · " + app.version)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 9) {
                if app.origin == "Saisie manuelle" {
                    Button {
                        model.saveManualDraft()
                    } label: {
                        Label("Enregistrer le brouillon", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("draft.save")
                }
                Menu {
                    Button {
                        model.exportReport()
                    } label: {
                        Label("Exporter en Markdown", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("export.markdown")

                    Button {
                        model.exportJSONLines()
                    } label: {
                        Label("Exporter en JSON Lines", systemImage: "curlybraces")
                    }
                    .disabled(model.observations.isEmpty)
                    .accessibilityIdentifier("export.jsonl")
                } label: {
                    Label("Exporter", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Notes générales")
                    .font(.headline)
                TextEditor(text: $model.notes)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120, maxHeight: 200)
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(.separator.opacity(0.35))
                    )
                    .accessibilityLabel("Notes générales, sans données privées")
                    .accessibilityIdentifier("observation.general-notes")
                Text("Évitez les identifiants personnels et autres informations confidentielles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Parcours observés")
                        .font(.headline)
                    Text("\(model.observations.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        model.addObservation()
                    } label: {
                        Label("Ajouter un parcours", systemImage: "plus")
                    }
                    .accessibilityIdentifier("observation.add")
                }

                if model.observations.isEmpty {
                    ContentUnavailableView(
                        "Aucun parcours",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Ajoutez un écran ou une action que vous avez observés.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach($model.observations) { $observation in
                        ObservationEditorRow(observation: $observation)
                    }
                }
            }
        }
    }
}

private struct ObservationEditorRow: View {
    @Binding var observation: Observation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Écran / parcours (ex. Connexion)", text: $observation.screenName)
                .font(.headline)
                .accessibilityIdentifier("observation.screen")
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Text("Action")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .leading)
                    TextField("Action effectuée", text: $observation.expectedAction)
                        .accessibilityIdentifier("observation.action")
                }
                GridRow {
                    Text("Résultat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .leading)
                    TextField("Résultat observé", text: $observation.observedResult)
                        .accessibilityIdentifier("observation.result")
                }
                GridRow {
                    Text("Limites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .leading)
                    TextField("Limites et remarques", text: $observation.notes)
                        .accessibilityIdentifier("observation.limitations")
                }
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(17)
        .background(Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10))
    }
}
