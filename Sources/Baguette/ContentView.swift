import SwiftUI
import WandCore

/// Contenu de la fenêtre : état vide ou canevas, barres, dépôt de fichier et alertes.
struct ContentView: View {
    @Bindable var model: AppModel
    @ViewState private var isDropTargeted = false

    var body: some View {
        ZStack {
            if let image = model.editor.image {
                Image(decorative: ImageFile.cgImage(image), scale: 1)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
            } else {
                EmptyState(open: model.showOpenPanel)
            }
        }
        .frame(minWidth: 520, minHeight: 380)
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
        .alert("Ignorer les modifications ?", isPresented: discardAlertBinding) {
            Button("Annuler", role: .cancel) { model.pendingURL = nil }
            Button("Ignorer", role: .destructive) { model.discardChangesAndOpenPending() }
        } message: {
            Text("Les modifications de l'image actuelle n'ont pas été exportées.")
        }
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
