import Foundation

struct AppSpecExporter {
    static func markdown(for app: InstalledApplication, observations: [Observation], generalNotes: String, date: Date = .now) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateText = formatter.string(from: date)
        func safe(_ value: String) -> String { value.replacingOccurrences(of: "\r", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
        var lines = [
            "# Fiche d'observation — \(safe(app.name))",
            "",
            "- Application : \(safe(app.name))",
            "- Bundle ID : `\(safe(app.id))`",
            "- Version observée : \(safe(app.version))",
            "- Date : \(dateText)",
            "- Niveau de preuve : **observation manuelle**, non audit logiciel",
            "- Provenance : inventaire local d'un appareil autorisé",
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
}
