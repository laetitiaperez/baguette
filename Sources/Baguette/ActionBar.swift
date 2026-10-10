import SwiftUI
import WandCore

/// Barre d'actions flottante (en bas au centre), visible tant qu'il y a une sélection.
struct ActionBar: View {
    let editor: Editor

    var body: some View {
        HStack(spacing: 2) {
            Button { editor.eraseSelection() } label: {
                Label("Effacer", systemImage: "eraser")
            }
            // ⌫ est traité par le canevas (premier répondeur), jamais comme raccourci :
            // il ne doit pas effacer l'image pendant la saisie dans un champ de texte.
            .help("Effacer la sélection (⌫)")

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 4)

            Button { editor.invertSelection() } label: {
                Label("Inverser", systemImage: "circle.lefthalf.filled")
            }
            .help("Inverser la sélection (⌘⇧I)")

            Button { editor.deselect() } label: {
                Label("Désélectionner", systemImage: "xmark.circle")
            }
            .help("Désélectionner (⌘D)")
        }
        .buttonStyle(BarButtonStyle())
        .labelStyle(.titleAndIcon)
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

/// Bouton sans bordure, surligné au survol et à l'appui.
private struct BarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BarButton(configuration: configuration)
    }

    private struct BarButton: View {
        let configuration: ButtonStyleConfiguration
        @ViewState private var isHovered = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.16 : isHovered ? 0.08 : 0))
                )
                .contentShape(Capsule())
                .onHover { isHovered = $0 }
        }
    }
}
