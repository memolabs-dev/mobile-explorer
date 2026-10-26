import SwiftUI

private enum Design {
    static let ink = Color(red: 0.09, green: 0.14, blue: 0.12)
    static let lime = Color(red: 0.77, green: 0.95, blue: 0.49)
    static let canvas = Color(red: 0.96, green: 0.965, blue: 0.95)
}

struct ContentView: View {
    @StateObject private var model = ExplorerModel()

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                brand
                HStack {
                    Text("APPAREILS").font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.refreshDevices() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).help("Actualiser")
                }.padding(.horizontal, 19).padding(.top, 28).padding(.bottom, 12)
                if model.devices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "iphone.gen3").font(.system(size: 32)).foregroundStyle(.secondary)
                        Text("Aucun iPhone connecté").font(.system(size: 13, weight: .semibold))
                        Text("Branchez-le au Mac, déverrouillez-le puis validez la confiance.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }.padding(20)
                } else {
                    ForEach(model.devices) { device in
                        Button {
                            model.selectDevice(device.id)
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "iphone.gen3").font(.title3)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name).font(.system(size: 13, weight: .bold))
                                    Text("\(device.model) · \(device.state)").font(.system(size: 11)).foregroundStyle(.secondary)
                                    Text(device.connectionHint).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(3)
                                }
                                Spacer(minLength: 0)
                            }.padding(12).background(model.selectedDeviceID == device.id ? Design.lime.opacity(0.42) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).padding(.horizontal, 8)
                    }
                }
                Divider().padding(.vertical, 19)
                HStack {
                    Text("APPLICATIONS").font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.applications.count)").font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 19).padding(.bottom, 10)
                Button { model.scanApplications() } label: {
                    Label("Lire les applications", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(Design.ink)
                .disabled(model.selectedDevice == nil || model.isBusy)
                .padding(.horizontal, 14).padding(.bottom, 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text("FICHE SANS IPHONE").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    TextField("Application autorisée", text: $model.manualAppName)
                    Button { model.createManualApp() } label: {
                        Label("Créer une fiche manuelle", systemImage: "square.and.pencil")
                    }
                    .disabled(model.manualAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let app = model.manualApplication {
                        Button { model.selectApplication(app.id) } label: {
                            Text(app.name + " · saisie manuelle")
                        }.buttonStyle(.borderless)
                    }
                }.textFieldStyle(.roundedBorder).padding(.horizontal, 14).padding(.bottom, 12)
                List(model.applications, selection: $model.selectedApplicationID) { app in
                    Button { model.selectApplication(app.id) } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 9).fill(Design.lime.opacity(0.5))
                                .frame(width: 34, height: 34)
                                .overlay(Text(String(app.name.prefix(1))).fontWeight(.bold))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name).font(.system(size: 12, weight: .semibold))
                                Text(app.id).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }.buttonStyle(.plain).listRowBackground(model.selectedApplicationID == app.id ? Design.lime.opacity(0.2) : Color.clear)
                }.listStyle(.plain)
                Spacer(minLength: 0)
                Text("LOCAL · AUCUNE DONNÉE TRANSMISE")
                    .font(.system(size: 9, weight: .medium)).tracking(1)
                    .foregroundStyle(.secondary).padding(18)
            }.background(Design.canvas)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("OBSERVATOIRE MOBILE / PROTOTYPE").font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(.secondary)
                        Spacer()
                        Label("LECTURE SEULE", systemImage: "lock.shield")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.green)
                    }
                    if let app = model.selectedApplication {
                        appWorkspace(app)
                    } else { emptyState }
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                    }
                    HStack(spacing: 8) {
                        if model.isBusy { ProgressView().controlSize(.small) }
                        Text(model.statusMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(36).frame(maxWidth: 890, alignment: .leading)
            }.background(Color.white)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 920, minHeight: 610)
        .onAppear { model.refreshDevices() }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9).fill(Design.ink).frame(width: 35, height: 35)
                .overlay(Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Design.lime))
            VStack(alignment: .leading, spacing: 0) {
                Text("mobile explorer").font(.system(size: 16, weight: .bold)).tracking(-0.6)
                Text("MEMO LABS / EXPERIMENTAL").font(.system(size: 8, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
            }
        }.padding(.horizontal, 18).padding(.top, 25)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comprendre une app,\nsans son code source.")
                .font(.system(size: 46, weight: .bold)).tracking(-2.3)
            Text("Connectez un iPhone ou créez une fiche manuelle pour documenter une application autorisée, même sans inventaire disponible.")
                .font(.system(size: 15)).foregroundStyle(.secondary).lineSpacing(6).frame(maxWidth: 560, alignment: .leading)
            HStack(spacing: 14) {
                capability("01", "Appareil détecté")
                capability("02", "Inventaire des apps")
                capability("03", "Fiche de parcours")
            }.padding(.top, 25)
            Text("Ce prototype ne déchiffre pas les applications, ne lit pas leurs données privées et ne pilote pas automatiquement les interfaces.")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 18)
        }.padding(.top, 70)
    }

    private func capability(_ number: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(number).font(.system(size: 12, weight: .heavy)).foregroundStyle(.green)
            Text(title).font(.system(size: 12, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).background(Design.canvas, in: RoundedRectangle(cornerRadius: 12))
    }

    private func appWorkspace(_ app: InstalledApplication) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FICHE D'OBSERVATION").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(.secondary)
                    Text(app.name).font(.system(size: 38, weight: .bold)).tracking(-1.7)
                    Text("\(app.id) · v\(app.version)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    Button { model.exportReport() } label: {
                        Label("Markdown", systemImage: "doc.text")
                    }
                    Button { model.exportJSONLines() } label: {
                        Label("JSON Lines", systemImage: "curlybraces")
                    }.disabled(model.observations.isEmpty)
                }.buttonStyle(.borderedProminent).tint(Design.ink)
            }
            Divider()
            Text("Notes générales").font(.headline)
            TextEditor(text: $model.notes)
                .font(.body).frame(minHeight: 100).padding(8)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(.gray.opacity(0.25)))
                .accessibilityLabel("Notes générales, sans données privées")
            HStack {
                Text("Parcours observés").font(.headline)
                Spacer()
                Button { model.addObservation() } label: { Label("Ajouter un parcours", systemImage: "plus") }
            }
            ForEach($model.observations) { $observation in
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Écran / parcours (ex. Connexion)", text: $observation.screenName)
                        .font(.system(size: 15, weight: .bold))
                    TextField("Action effectuée", text: $observation.expectedAction)
                    TextField("Résultat observé", text: $observation.observedResult)
                    TextField("Limites et remarques", text: $observation.notes)
                }.textFieldStyle(.roundedBorder).padding(16)
                    .background(Design.canvas, in: RoundedRectangle(cornerRadius: 12))
            }
            if model.observations.isEmpty {
                Text("Aucun parcours enregistré. Ajoutez le premier écran que vous avez observé manuellement.")
                    .font(.caption).foregroundStyle(.secondary).padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Design.canvas, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
