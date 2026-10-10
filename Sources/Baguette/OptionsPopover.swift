import SwiftUI

/// Options de la baguette : Contigu, Lisser les bords, Contour progressif.
struct OptionsPopover: View {
    @Binding var contiguous: Bool
    @Binding var antiAlias: Bool
    @Binding var featherRadius: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Contigu", isOn: $contiguous)
                .help("Ne sélectionner que la zone reliée au pixel cliqué")
            Toggle("Lisser les bords", isOn: $antiAlias)
                .help("Adoucir le bord de la sélection (anticrénelage)")
            Divider()
                .padding(.vertical, 2)
            HStack {
                Text("Contour progressif")
                Spacer()
                Text("\(Int(featherRadius)) px")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { featherRadius },
                                  set: { featherRadius = $0.rounded() }),
                   in: 0...50)
                .help("Rayon de fondu du bord de la sélection, en pixels")
        }
        .toggleStyle(.checkbox)
        .padding(16)
        .frame(width: 260)
    }
}
