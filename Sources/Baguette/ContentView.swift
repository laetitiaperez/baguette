import SwiftUI
import WandCore

/// Contenu de la fenêtre : état vide ou canevas, barres, dépôt de fichier et alertes.
struct ContentView: View {
    @Bindable var model: AppModel
    @ViewState private var isDropTargeted = false
    /// Gestionnaire d'annulation de la fenêtre, confié à l'éditeur (Édition › Annuler / Rétablir).
    @Environment(\.undoManager) private var undoManager

    // Réglages mémorisés, recopiés dans l'éditeur.
    @AppStorage("tolerance") private var tolerance = 32
    @AppStorage("contiguous") private var contiguous = true
    @AppStorage("antiAlias") private var antiAlias = true
    @AppStorage("featherRadius") private var featherRadius = 0.0

    var body: some View {
        ZStack {
            if model.editor.image != nil {
                CanvasView(model: model, image: model.editor.image, selection: model.editor.selection)
            } else {
                EmptyState(open: model.showOpenPanel)
            }
        }
        .overlay(alignment: .bottom) {
            // Le toast se place au-dessus de la barre d'actions quand les deux sont visibles.
            VStack(spacing: 12) {
                if let toast = model.toast {
                    Toast(message: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if model.hasSelection {
                    ActionBar(editor: model.editor)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 20)
        }
        .animation(.spring(duration: 0.3), value: model.hasSelection)
        .animation(.easeOut(duration: 0.25), value: model.toast)
        .toolbar {
            if model.hasImage {
                TopBar(tolerance: $tolerance, contiguous: $contiguous,
                       antiAlias: $antiAlias, featherRadius: $featherRadius,
                       canExport: model.hasImage, export: model.showExportPanel)
            }
        }
        .toolbar(model.hasImage ? .visible : .hidden, for: .windowToolbar)
        .navigationTitle(model.fileURL?.lastPathComponent ?? "Baguette")
        .onChange(of: undoManager.map(ObjectIdentifier.init), initial: true) {
            undoManager?.levelsOfUndo = 50  // borne la mémoire : chaque pas garde image et masques entiers
            model.editor.undoManager = undoManager
        }
        .onChange(of: tolerance, initial: true) { model.editor.tolerance = min(max(tolerance, 0), 255) }
        .onChange(of: contiguous, initial: true) { model.editor.contiguous = contiguous }
        .onChange(of: antiAlias, initial: true) { model.editor.antiAlias = antiAlias }
        .onChange(of: featherRadius, initial: true) { model.editor.featherRadius = min(max(featherRadius, 0), 50) }
        .frame(minWidth: 620, minHeight: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay { if isDropTargeted { DropHighlight() } }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.open(url)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .alert("Impossible d'ouvrir cette image", isPresented: $model.showsLoadError) {
            Button("OK", role: .cancel) {}
        }
        .alert("Impossible d'exporter l'image", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.exportError ?? "")
        }
        .alert("Ignorer les modifications ?", isPresented: discardAlertBinding) {
            Button("Annuler", role: .cancel) { model.pendingURL = nil }
            Button("Ignorer", role: .destructive) { model.discardChangesAndOpenPending() }
        } message: {
            Text("Les modifications de l'image actuelle n'ont pas été exportées.")
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(get: { model.exportError != nil },
                set: { if !$0 { model.exportError = nil } })
    }

    private var discardAlertBinding: Binding<Bool> {
        Binding(get: { model.pendingURL != nil },
                set: { if !$0 { model.pendingURL = nil } })
    }
}

/// État vide : invitation à déposer ou ouvrir une image.
private struct EmptyState: View {
    let open: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            Text("Glisse une image ici")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button(action: open) {
                HStack(spacing: 6) {
                    Text("Ouvrir…")
                    Text("⌘O").foregroundStyle(.secondary)
                }
            }
            .controlSize(.large)
        }
        .padding(40)
    }
}

/// Surbrillance pointillée en couleur d'accent pendant un glisser-déposer.
private struct DropHighlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
            .padding(10)
            .allowsHitTesting(false)
    }
}
