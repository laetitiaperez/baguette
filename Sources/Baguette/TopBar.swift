import SwiftUI

/// Barre du haut, intégrée à la barre de titre : le nom du fichier est le titre de la fenêtre (à gauche) ;
/// à droite, tolérance, options et, tout à droite, le bouton Exporter (même action que ⌘⇧E).
struct TopBar: ToolbarContent {
    @Binding var tolerance: Int
    @Binding var contiguous: Bool
    @Binding var antiAlias: Bool
    @Binding var featherRadius: Double
    let canExport: Bool
    let export: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ToleranceControl(tolerance: $tolerance)
        }
        ToolbarItem(placement: .primaryAction) {
            OptionsButton(contiguous: $contiguous, antiAlias: $antiAlias, featherRadius: $featherRadius)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: export) {
                Label("Exporter", systemImage: "square.and.arrow.up")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .help("Exporter en PNG (⌘⇧E)")
            .disabled(!canExport)
        }
    }
}

/// Curseur Tolérance (0–255, pas de 1) avec sa valeur.
private struct ToleranceControl: View {
    @Binding var tolerance: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("Tolérance")
                .foregroundStyle(.secondary)
            Slider(value: Binding(get: { Double(tolerance) },
                                  set: { tolerance = Int($0.rounded()) }),
                   in: 0...255)
                .frame(width: 140)
            Text("\(tolerance)")
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .help("Écart de couleur accepté autour du pixel cliqué (0–255)")
    }
}

/// Bouton ⚙︎ ouvrant le popover d'options.
private struct OptionsButton: View {
    @Binding var contiguous: Bool
    @Binding var antiAlias: Bool
    @Binding var featherRadius: Double
    @ViewState private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Options", systemImage: "gearshape")
        }
        .help("Options de sélection")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            OptionsPopover(contiguous: $contiguous, antiAlias: $antiAlias, featherRadius: $featherRadius)
        }
    }
}
