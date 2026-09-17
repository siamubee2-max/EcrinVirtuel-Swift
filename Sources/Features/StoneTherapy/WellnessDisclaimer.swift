import SwiftUI

/// Legal notice shown wherever the app presents lithotherapy claims.
///
/// The stone guide describes traditional virtues (chakras, healing, stress,
/// anxiety). App Review treats unqualified wellness claims as health claims,
/// so every screen carrying them must also carry this notice.
struct WellnessDisclaimer: View {
    var body: some View {
        HStack(alignment: .top, spacing: EcrinSpacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(EcrinColor.gold)

            // textSecondary et non textMuted : ce dernier vise AA sur le fond
            // #080808 de l'app, mais cette carte est posée sur `surface`, plus
            // clair, où il retombe à 4,47:1 — sous le seuil AA. Ici : ~4,95:1.
            Text(L10n.StoneTherapyUI.wellnessDisclaimer)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EcrinSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(EcrinColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(EcrinColor.gold.opacity(0.06))
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}
