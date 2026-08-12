import SwiftUI

// MARK: - Occasion Vault View

struct OccasionVaultView: View {
    @StateObject private var viewModel = OccasionVaultViewModel()
    @State private var selectedLook: SavedLook?
    @State private var showSaveLookSheet = false
    @Namespace private var tabNS

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.md)

                occasionTabs
                    .padding(.bottom, EcrinSpacing.md)

                looksGrid
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    fab
                        .padding(.trailing, EcrinSpacing.lg)
                        .padding(.bottom, EcrinSpacing.xl)
                }
            }

            // Toast
            if let msg = viewModel.toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.background)
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.vertical, EcrinSpacing.md)
                        .background(EcrinColor.gold)
                        .clipShape(Capsule())
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(EcrinAnimation.springSnap, value: viewModel.toastMessage)
            }
        }
        .sheet(item: $selectedLook) { look in
            LookDetailView(viewModel: viewModel, look: look)
        }
        .sheet(isPresented: $showSaveLookSheet) {
            SaveLookSheet(
                previewImageData: nil,
                preselectedJewelry: JewelryItem.samples
            ) { newLook in
                withAnimation(EcrinAnimation.springSnap) {
                    viewModel.saveLook(newLook)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.OccasionVaultUI.myDressingTitle)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(L10n.OccasionVaultUI.yourSavedLooks)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }

            Spacer()

            GlassCard(cornerRadius: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(EcrinColor.gold)
                    Text("\(viewModel.savedLooks.count) looks")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                }
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.vertical, EcrinSpacing.sm)
            }
        }
    }

    // MARK: - Occasion Tabs (horizontal scroll)

    private var occasionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(LookOccasion.allCases, id: \.self) { occasion in
                    OccasionTabButton(
                        occasion: occasion,
                        count: viewModel.count(for: occasion),
                        isSelected: viewModel.selectedOccasion == occasion,
                        namespace: tabNS
                    ) {
                        withAnimation(.spring) {
                            viewModel.selectedOccasion = occasion
                        }
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Looks Grid

    private var looksGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: EcrinSpacing.md),
            GridItem(.flexible(), spacing: EcrinSpacing.md)
        ]

        return ScrollView(showsIndicators: false) {
            if viewModel.filteredLooks.isEmpty {
                emptyState
                    .padding(.top, EcrinSpacing.xxl)
            } else {
                LazyVGrid(columns: columns, spacing: EcrinSpacing.md) {
                    ForEach(viewModel.filteredLooks) { look in
                        SavedLookCard(
                            look: look,
                            onFavorite: {
                                viewModel.toggleFavorite(look)
                            },
                            onTap: {
                                selectedLook = look
                            },
                            onEdit: {
                                selectedLook = look
                            },
                            onDuplicate: {
                                viewModel.duplicateLook(look)
                            },
                            onDelete: {
                                viewModel.deleteLook(look)
                            }
                        )
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.bottom, 100)
            }
        }
        .id(viewModel.selectedOccasion)
        .animation(.spring, value: viewModel.selectedOccasion)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.lg) {
            ZStack {
                Circle()
                    .fill(viewModel.selectedOccasion.accentColor.opacity(0.08))
                    .frame(width: 96, height: 96)
                Image(systemName: viewModel.selectedOccasion.icon)
                    .font(.system(size: 38, weight: .thin))
                    .foregroundStyle(viewModel.selectedOccasion.accentColor.opacity(0.5))
            }

            VStack(spacing: EcrinSpacing.sm) {
                Text("Aucun look \(viewModel.selectedOccasion.rawValue.lowercased())")
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textSecondary)
                Text(L10n.OccasionVaultUI.emptyVaultHint)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textMuted)
                    .multilineTextAlignment(.center)
            }

            GoldButton(title: L10n.OutfitBuilderUI.createALook) {
                showSaveLookSheet = true
            }
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button(action: { showSaveLookSheet = true }) {
            ZStack {
                Circle()
                    .fill(EcrinColor.gold)
                    .frame(width: 56, height: 56)
                    .shadow(color: EcrinColor.gold.opacity(0.35), radius: 16, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(EcrinColor.background)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Occasion Tab Button

private struct OccasionTabButton: View {
    let occasion: LookOccasion
    let count: Int
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: EcrinSpacing.xs) {
                Image(systemName: occasion.icon)
                    .font(.system(size: 12, weight: isSelected ? .medium : .light))
                    .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textMuted)

                Text(occasion.rawValue)
                    .font(EcrinFont.cta)
                    .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textMuted)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? EcrinColor.background.opacity(0.7) : EcrinColor.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? EcrinColor.background.opacity(0.2) : EcrinColor.glassFill)
                        )
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background {
                if isSelected {
                    Capsule()
                        .fill(occasion.accentColor)
                        .matchedGeometryEffect(id: "tab_bg", in: namespace)
                } else {
                    Capsule()
                        .fill(EcrinColor.glassFill)
                        .overlay {
                            Capsule()
                                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring, value: isSelected)
    }
}
