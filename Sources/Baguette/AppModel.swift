import AppKit
import Observation
import UniformTypeIdentifiers
import WandCore

/// État de l'app partagé entre la fenêtre et les menus : l'éditeur, le fichier ouvert,
/// les alertes d'ouverture et d'export, le toast et l'accès au canevas pour le zoom.
@MainActor @Observable
final class AppModel {
    let editor = Editor()
    /// Fichier actuellement affiché.
    private(set) var fileURL: URL?
    /// Image en attente de confirmation (« Ignorer les modifications ? »).
    var pendingURL: URL?
    /// Alerte « Impossible d'ouvrir cette image ».
    var showsLoadError = false
    /// Message de l'alerte d'échec d'export (message système).
    var exportError: String?
    /// Toast affiché en bas de la fenêtre (« Exporté »), masqué automatiquement après 2 s.
    private(set) var toast: String?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    /// Vue de dessin du canevas, pour les commandes de zoom (posée par `CanvasView`).
    @ObservationIgnored weak var canvas: CanvasNSView?

    var hasImage: Bool { editor.image != nil }
    var hasSelection: Bool { editor.selection != nil }

    // MARK: - Ouverture

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self, weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            self?.open(url)
        }
        if let window = Self.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    /// Ouvre une image, en demandant confirmation si l'image actuelle a des modifications non exportées.
    func open(_ url: URL) {
        guard url.isFileURL else {
            showsLoadError = true
            return
        }
        if editor.isDirty {
            pendingURL = url
        } else {
            load(url)
        }
    }

    /// Réponse « Ignorer » à l'alerte de confirmation.
    func discardChangesAndOpenPending() {
        guard let url = pendingURL else { return }
        pendingURL = nil
        load(url)
    }

    private func load(_ url: URL) {
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try ImageFile.load(contentsOf: url) }
            }.value
            switch result {
            case .success(let image):
                canvas?.zoomToFit()
                editor.load(image)
                fileURL = url
            case .failure:
                showsLoadError = true
            }
        }
    }

    // MARK: - Export

    /// Nom proposé pour l'export : `<nom>-baguette.png`.
    var exportFileName: String { Exporter.suggestedName(for: fileURL) }

    /// ⌘⇧E / bouton Exporter : panneau d'enregistrement (en feuille sur la fenêtre), puis écriture du PNG.
    func showExportPanel() {
        guard editor.image != nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = exportFileName
        panel.directoryURL = fileURL?.deletingLastPathComponent()
        panel.canCreateDirectories = true
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self, weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            self?.export(to: url)
        }
        if let window = Self.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    /// Écrit l'image courante en PNG ; succès → image marquée exportée + toast, échec → alerte.
    func export(to url: URL) {
        guard let image = editor.image else { return }
        do {
            try Exporter.write(image, to: url)
            didExport(image)
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Glisser hors du canevas (⌘ + glisser) : promesse de fichier PNG pour l'image courante.
    func dragPromise() -> PNGFilePromise? {
        guard let image = editor.image else { return nil }
        return PNGFilePromise(image: image, fileName: exportFileName,
                              onWritten: { [weak self] in self?.didExport(image) },
                              onFailure: { [weak self] in self?.exportError = $0.localizedDescription })
    }

    /// L'image exportée n'est marquée « exportée » que si elle est toujours celle affichée.
    private func didExport(_ image: RGBAImage) {
        if editor.image == image { editor.markExported() }
        showToast("Exporté")
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    /// Fenêtre principale de l'app (hors panneaux), pour y attacher les feuilles.
    static var mainWindow: NSWindow? {
        NSApp.keyWindow.flatMap { $0 is NSPanel ? nil : $0 } ?? NSApp.mainWindow
            ?? NSApp.windows.first { $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel) }
    }

    // MARK: - Zoom

    func zoomIn() { canvas?.zoom(by: 1.25) }
    func zoomOut() { canvas?.zoom(by: 1 / 1.25) }
    func zoomToFit() { canvas?.zoomToFit() }
}
