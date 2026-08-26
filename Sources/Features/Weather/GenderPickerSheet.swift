import SwiftUI

// MARK: - GenderPickerSheet

struct GenderPickerSheet: View {
    let onSelect: (ClothingGender) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                VStack(spacing: EcrinSpacing.sm) {
                    Text(L10n.LookOfDay.yourStyle)
                        .font(EcrinFont.label)
                        .kerning(3)
                        .foregroundStyle(EcrinColor.gold)
                    Text(L10n.LookOfDay.genderQuestion)
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, EcrinSpacing.xl)

                HStack(spacing: EcrinSpacing.md) {
                    genderButton(.femme)
                    genderButton(.homme)
                }
                .padding(.horizontal, EcrinSpacing.lg)

                Text(L10n.LookOfDay.genderChangeHint)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EcrinSpacing.lg)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func genderButton(_ gender: ClothingGender) -> some View {
        Button {
            onSelect(gender)
            dismiss()
        } label: {
            GlassCard(cornerRadius: 20) {
                VStack(spacing: EcrinSpacing.md) {
                    Image(systemName: gender.icon)
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(gender.color)
                    Text(gender.label)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, EcrinSpacing.xl)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choisir \(gender.label)")
    }
}
