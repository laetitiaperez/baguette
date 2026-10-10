import SwiftUI

/// Petite notification en bas au centre (« Exporté »), qui apparaît et disparaît en fondu + glissement.
struct Toast: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
        .allowsHitTesting(false)
        .accessibilityAddTraits(.isStaticText)
    }
}
