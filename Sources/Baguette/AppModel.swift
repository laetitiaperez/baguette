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
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    /// Ouvre une image, en demandant confirmation si l'image actuelle a des modifications non exportées.
    func open(_ url: URL) {
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
                editor.load(image)
                fileURL = url
            case .failure:
                showsLoadError = true
            }
        }
    }
}
