import SwiftUI

// MARK: - BudgetPickerSheet

/// Compact bottom sheet for selecting a maximum budget for look recommendations.
/// Tiers: nil (all prices), 50€, 100€, 200€, 500€.
struct BudgetPickerSheet: View {

    let selectedBudget: Double?
    let tiers: [Double?]
    let onSelect: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(EcrinColor.textMuted.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text(L10n.LookOfDay.budgetTitle)
                .font(EcrinFont.sectionHead)
                .foregroundStyle(EcrinColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, EcrinSpacing.lg)

            Text(L10n.LookOfDay.budgetDesc)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.top, 4)
                .padding(.bottom, EcrinSpacing.md)

            // Tier pills
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(tiers.indices, id: \.self) { idx in
                    let tier = tiers[idx]
                    let isSelected = selectedBudget == tier
                    Button {
                        onSelect(tier)
                        dismiss()
                    } label: {
                        Text(tier == nil ? L10n.DemoGallery.categoriesAll : "\(Int(tier!))€")
                            .font(EcrinFont.sans(14, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                isSelected
                                    ? EcrinColor.gold
                                    : EcrinColor.surface,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.lg)

            Spacer()
        }
        .background(EcrinColor.background)
    }
}
