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
                .background(WindowReader { appDelegate.guardClosing(of: $0) })
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 960, height: 680)
        .commands { BaguetteCommands(model: model) }
    }
}

/// Fenêtre unique : pas d'onglets, l'app se ferme avec sa fenêtre, les fichiers ouverts depuis le Finder
/// arrivent dans la fenêtre existante. Fermer la fenêtre ou quitter avec des modifications non exportées
/// demande confirmation (une seule fois : fermer la fenêtre passe par la même question que ⌘Q).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel? {
        didSet { flushPendingURLs() }
    }
    private var pendingURLs: [URL] = []
    private var closeGuard: WindowCloseGuard?
    private var menuObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI ajoute un élément système « Toggle Sidebar ⌘S » (en anglais, dans Aide) alors que l'app
        // n'a pas de barre latérale : on le retire, maintenant et chaque fois que SwiftUI reconstruit les menus.
        removeSidebarItems()
        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.removeSidebarItems() }
        }
    }

    private func removeSidebarItems() {
        func sweep(_ menu: NSMenu) {
            for item in menu.items {
                if item.action == #selector(NSSplitViewController.toggleSidebar(_:)) {
                    menu.removeItem(item)
                } else if let submenu = item.submenu {
                    sweep(submenu)
                }
            }
        }
        if let mainMenu = NSApp.mainMenu { sweep(mainMenu) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Quitter / fermer sans exporter

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.editor.isDirty else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Quitter sans exporter ?"
        alert.informativeText = "Les modifications de l'image actuelle n'ont pas été exportées."
        alert.addButton(withTitle: "Annuler")
        let quit = alert.addButton(withTitle: "Quitter")
        quit.hasDestructiveAction = true
        alert.buttons[0].keyEquivalent = "\u{1b}"
        if let window = AppModel.mainWindow, window.attachedSheet == nil {
            alert.beginSheetModal(for: window) { response in
                NSApp.reply(toApplicationShouldTerminate: response == .alertSecondButtonReturn)
            }
            return .terminateLater
        }
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    /// Le bouton de fermeture (ou ⌘W) passe par `applicationShouldTerminate` quand l'image n'a pas été
    /// exportée : la fenêtre unique ne se ferme alors qu'avec l'app, après une seule confirmation.
    func guardClosing(of window: NSWindow) {
        guard closeGuard?.window !== window else { return }
        closeGuard = WindowCloseGuard(window: window) { [weak self] in
            guard let model = self?.model, model.editor.isDirty else { return true }
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return false
        }
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
        // Après Ouvrir… : le groupe `.saveItem` contient aussi Fermer ⌘W, qu'il faut garder.
        CommandGroup(after: .newItem) {
            Button("Exporter…") { model.showExportPanel() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!model.hasImage)
        }
        CommandGroup(after: .pasteboard) {
            // Pas d'équivalent clavier : ⌫ est géré par le canevas (voir CanvasNSView.keyDown),
            // pour ne jamais effacer l'image pendant la saisie dans un champ de texte ou un panneau.
            Button("Effacer (⌫)") { model.editor.eraseSelection() }
                .disabled(!model.hasSelection)
            Button("Inverser") { model.editor.invertSelection() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(!model.hasImage)
            Button("Désélectionner") { model.editor.deselect() }
                .keyboardShortcut("d")
                .disabled(!model.hasSelection)
        }
        CommandGroup(before: .toolbar) {
            // ⌘= zoome ; ⌘+ (⌘⇧=) est géré par le canevas (CanvasNSView.performKeyEquivalent).
            Button("Zoom avant") { model.zoomIn() }
                .keyboardShortcut("=")
                .disabled(!model.hasImage)
            Button("Zoom arrière") { model.zoomOut() }
                .keyboardShortcut("-")
                .disabled(!model.hasImage)
            Button("Ajuster") { model.zoomToFit() }
                .keyboardShortcut("0")
                .disabled(!model.hasImage)
            Divider()
        }
    }
}

/// Délégué intercalé devant celui que SwiftUI donne à la fenêtre : il répond à `windowShouldClose`
/// et transmet tout le reste au délégué d'origine.
@MainActor
final class WindowCloseGuard: NSObject, NSWindowDelegate {
    private(set) weak var window: NSWindow?
    // Lu seulement depuis le fil principal (messages de délégué de fenêtre).
    nonisolated(unsafe) private let original: NSWindowDelegate?
    private let shouldClose: () -> Bool

    init(window: NSWindow, shouldClose: @escaping () -> Bool) {
        self.window = window
        self.original = window.delegate
        self.shouldClose = shouldClose
        super.init()
        window.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard shouldClose() else { return false }
        return original?.windowShouldClose?(sender) ?? true
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
    }
}

/// Donne accès à la fenêtre qui contient la vue SwiftUI.
private struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {}

    final class ReaderView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // Laisser SwiftUI installer son propre délégué avant d'intercaler le nôtre.
            DispatchQueue.main.async { [weak self] in self?.onWindow?(window) }
        }
    }
}
