import Foundation

struct AppSpecExporter {
    static func markdown(for app: InstalledApplication, observations: [Observation], generalNotes: String, date: Date = .now) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateText = formatter.string(from: date)
        let bundleDisplay = app.origin == "Saisie manuelle" ? "non renseigné" : app.id
        func safe(_ value: String) -> String { value.replacingOccurrences(of: "\r", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
        var lines = [
            "# Fiche d'observation — \(safe(app.name))",
            "",
            "- Application : \(safe(app.name))",
            "- Bundle ID : `\(safe(bundleDisplay))`",
            "- Version observée : \(safe(app.version))",
            "- Date : \(dateText)",
            "- Niveau de preuve : **observation manuelle**, non audit logiciel",
            "- Provenance : \(app.origin == "Saisie manuelle" ? "saisie manuelle, sans inventaire" : "inventaire local d'un appareil autorisé")",
            "",
            "> Ce document ne contient ni code source, ni données privées, ni preuve de compatibilité complète.",
            "",
            "## Notes générales", "", safe(generalNotes.isEmpty ? "Non renseignées." : generalNotes), "",
            "## Parcours observés", ""
        ]
        if observations.isEmpty { lines.append("Aucun parcours consigné.") }
        for (index, item) in observations.enumerated() {
            lines += [
                "### \(index + 1). \(safe(item.screenName.isEmpty ? "Écran non nommé" : item.screenName))",
                "", "- Action : \(safe(item.expectedAction))", "- Résultat observé : \(safe(item.observedResult))",
                "- Notes : \(safe(item.notes))", ""
            ]
        }
        lines += ["## Limites", "", "Les parcours non visités ne sont pas documentés. Les backends et comportements internes ne sont pas inférables de cette seule observation.", ""]
        return lines.joined(separator: "\n")
    }

    // Every JSONL line is an independent v0.1 observation. No test is claimed.
    static func jsonLines(for app: InstalledApplication, observations: [Observation], generalNotes: String, date: Date = .now) throws -> String {
        guard !observations.isEmpty else { throw ExplorerError.invalidData("Aucune observation à exporter") }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: date)
        var rows: [String] = []
        for (index, item) in observations.enumerated() {
            let capability = item.screenName.trimmingCharacters(in: .whitespacesAndNewlines)
            var subject: [String: Any] = ["name": app.name, "kind": "authorized-test-app"]
            if app.origin != "Saisie manuelle" { subject["bundleId"] = app.id }
            if !app.version.isEmpty && app.version != "inconnue" && app.version != "—" {
                subject["version"] = app.version
            }
            var limitations = ["Observation manuelle : aucun test indépendant ni compatibilité vérifiée."]
            if !item.expectedAction.isEmpty { limitations.append("Action : " + item.expectedAction) }
            if !item.observedResult.isEmpty { limitations.append("Résultat déclaré : " + item.observedResult) }
            if !item.notes.isEmpty { limitations.append("Notes : " + item.notes) }
            if !generalNotes.isEmpty { limitations.append("Notes générales : " + generalNotes) }
            let payload: [String: Any] = [
                "schemaVersion": "0.1",
                "subject": subject,
                "capability": capability.isEmpty ? "Parcours \(index + 1)" : capability,
                "claimStatus": "unknown",
                "collectedAt": timestamp,
                "source": ["type": "manual-observation", "reference": "local-observation-\(index + 1)"],
                "limitations": limitations
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            guard let row = String(data: data, encoding: .utf8) else {
                throw ExplorerError.invalidData("Impossible d'encoder le JSON")
            }
            rows.append(row)
        }
        return rows.joined(separator: "\n") + "\n"
    }

}
