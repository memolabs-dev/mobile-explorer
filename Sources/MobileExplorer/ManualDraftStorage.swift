import Foundation
import Darwin

/// Explicit user-selected files only. Never persists an iPhone identifier or uploads notes.
enum ManualDraftStorage {
    static func save(_ data: Data, to destination: URL, maximumBytes: Int = ManualDraftCodec.maximumBytes) throws {
        guard destination.isFileURL, data.count <= maximumBytes else {
            throw ExplorerError.invalidData("Destination ou taille du brouillon invalide.")
        }
        // Create with mode 0600 BEFORE writing private notes, not afterwards.
        // Using an exclusive temporary file in the same folder permits an atomic rename.
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".mobile-explorer-\(UUID().uuidString).tmp")
        let descriptor = Darwin.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
        guard descriptor >= 0 else {
            throw ExplorerError.commandFailed("Impossible de créer un fichier privé à l'emplacement choisi.")
        }
        var renamed = false
        defer {
            if !renamed { try? FileManager.default.removeItem(at: temporary) }
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
        guard Darwin.rename(temporary.path, destination.path) == 0 else {
            throw ExplorerError.commandFailed("Impossible de finaliser le brouillon sans toucher au fichier existant.")
        }
        renamed = true
    }

    static func load(from source: URL) throws -> ManualObservationDraft {
        guard source.isFileURL else {
            throw ExplorerError.invalidData("Choisir un fichier local.")
        }
        // Bounded read even if another process changes the file after selection.
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: ManualDraftCodec.maximumBytes + 1) ?? Data()
        return try ManualDraftCodec.decode(bytes)
    }
}
