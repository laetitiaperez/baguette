import AppKit
import Observation
import UniformTypeIdentifiers
import WandCore

/// État de l'app partagé entre la fenêtre et les menus : l'éditeur, le fichier ouvert,
/// les alertes d'ouverture et l'accès au canevas pour le zoom.
@MainActor @Observable
final class AppModel {
    let editor = Editor()
    /// Fichier actuellement affiché.
    private(set) var fileURL: URL?
    /// Image en attente de confirmation (« Ignorer les modifications ? »).
    var pendingURL: URL?
    /// Alerte « Impossible d'ouvrir cette image ».
    var showsLoadError = false

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
        let window = NSApp.keyWindow ?? NSApp.mainWindow
            ?? NSApp.windows.first { $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel) }
        if let window {
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

    // MARK: - Zoom

    func zoomIn() { canvas?.zoom(by: 1.25) }
    func zoomOut() { canvas?.zoom(by: 1 / 1.25) }
    func zoomToFit() { canvas?.zoomToFit() }
}
