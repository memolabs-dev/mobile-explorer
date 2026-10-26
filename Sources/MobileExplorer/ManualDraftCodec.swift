import Foundation

/// An explicit, local-only work-in-progress draft. No device or bundle identifier is persisted.
struct ManualObservationDraft: Codable, Equatable {
    static let version = "1"
    let schemaVersion: String
    let applicationName: String
    let generalNotes: String
    let steps: [Step]

    struct Step: Codable, Equatable {
        let screenName: String
        let expectedAction: String
        let observedResult: String
        let notes: String
    }
}

enum ManualDraftCodec {
    static let maximumBytes = 1_048_576
    static let maximumSteps = 100

    static func encode(app: InstalledApplication, observations: [Observation], notes: String) throws -> Data {
        guard app.origin == "Saisie manuelle" else {
            throw ExplorerError.invalidData("Les brouillons privés sont réservés aux fiches manuelles.")
        }
        let draft = ManualObservationDraft(
            schemaVersion: ManualObservationDraft.version,
            applicationName: app.name,
            generalNotes: notes,
            steps: observations.map { .init(
                screenName: $0.screenName,
                expectedAction: $0.expectedAction,
                observedResult: $0.observedResult,
                notes: $0.notes
            ) }
        )
        try validate(draft)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(draft)
        guard bytes.count <= maximumBytes else {
            throw ExplorerError.invalidData("Brouillon trop volumineux (1 Mio maximum).")
        }
        return bytes
    }

    static func decode(_ data: Data) throws -> ManualObservationDraft {
        guard data.count <= maximumBytes else {
            throw ExplorerError.invalidData("Brouillon trop volumineux (1 Mio maximum).")
        }
        let draft = try JSONDecoder().decode(ManualObservationDraft.self, from: data)
        try validate(draft)
        return draft
    }

    static func restoredObservations(_ draft: ManualObservationDraft) -> [Observation] {
        draft.steps.map { Observation(
            screenName: $0.screenName,
            expectedAction: $0.expectedAction,
            observedResult: $0.observedResult,
            notes: $0.notes
        ) }
    }

    private static func validate(_ draft: ManualObservationDraft) throws {
        guard draft.schemaVersion == ManualObservationDraft.version else {
            throw ExplorerError.invalidData("Version de brouillon non prise en charge.")
        }
        let name = draft.applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty && name.count <= 120 else {
            throw ExplorerError.invalidData("Nom d'application manquante ou trop long.")
        }
        guard draft.generalNotes.count <= 20_000, draft.steps.count <= maximumSteps else {
            throw ExplorerError.invalidData("Nombre de parcours ou longueur de notes dépassé.")
        }
        for step in draft.steps {
            guard [step.screenName, step.expectedAction, step.observedResult, step.notes].allSatisfy({ $0.count <= 4_000 }) else {
                throw ExplorerError.invalidData("Un champ de parcours dépasse 4 000 caractères.")
            }
        }
    }
}
