import AppKit
import SwiftUI
import WandCore

/// Avec les seules Command Line Tools, le plugin de macros SwiftUI (`@State` y est une macro) est absent :
/// on passe par un alias pour utiliser directement le property wrapper `State`.
typealias ViewState = SwiftUI.State

@main
struct BaguetteApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @ViewState private var model = AppModel()

    var body: some Scene {
        Window("Baguette", id: "main") {
            ContentView(model: model)
                .onAppear { appDelegate.model = model }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 960, height: 680)
        .commands { BaguetteCommands(model: model) }
    }
}

/// Fenêtre unique : pas d'onglets, l'app se ferme avec sa fenêtre, les fichiers ouverts depuis le Finder
/// arrivent dans la fenêtre existante.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel? {
        didSet { flushPendingURLs() }
    }
    private var pendingURLs: [URL] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        pendingURLs = urls
        flushPendingURLs()
    }

    private func flushPendingURLs() {
        guard let model, let url = pendingURLs.first else { return }
        pendingURLs = []
        model.open(url)
    }
}

struct BaguetteCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Ouvrir…") { model.showOpenPanel() }
                .keyboardShortcut("o")
        }
        CommandGroup(before: .toolbar) {
            Button("Zoom avant") { model.zoomIn() }
                .keyboardShortcut("+")
                .disabled(!model.hasImage)
            Button("Zoom arrière") { model.zoomOut() }
                .keyboardShortcut("-")
                .disabled(!model.hasImage)
            Button("Ajuster à la fenêtre") { model.zoomToFit() }
                .keyboardShortcut("0")
                .disabled(!model.hasImage)
            Divider()
        }
    }
}
