import SwiftUI

// MARK: - PoseSelectorView

struct PoseSelectorView: View {
    let fashionCategory: FashionCategory
    var vm: MultiPoseViewModel

    @State private var activeCategory: PoseCategory = .angle

    private var groupedPoses: [(category: PoseCategory, poses: [PoseVariant])] {
        PoseVariant.groupedPoses(for: fashionCategory)
    }

    private var availableCategories: [PoseCategory] {
        groupedPoses.map(\.category)
    }

    private var posesForActiveCategory: [PoseVariant] {
        groupedPoses.first(where: { $0.category == activeCategory })?.poses ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            categoryTabs
                .padding(.top, EcrinSpacing.md)
                .padding(.horizontal, EcrinSpacing.lg)

            poseGrid
                .padding(.top, EcrinSpacing.md)

            if !vm.selectedPoses.isEmpty {
                selectionStrip
                    .padding(.top, EcrinSpacing.md)
                    .padding(.horizontal, EcrinSpacing.lg)
            }

            counterBadge
                .padding(.top, EcrinSpacing.sm)
                .padding(.bottom, EcrinSpacing.md)
        }
        .onAppear {
            if let first = availableCategories.first {
                activeCategory = first
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("CHOISIR VOS VUES")
                .font(EcrinFont.label)
                .kerning(3)
                .foregroundStyle(EcrinColor.gold)
            Text("Sélectionnez 1 à \(MultiPoseViewModel.maxPoses) poses")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }

    // MARK: - Category tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(availableCategories) { cat in
                    CategoryTab(
                        category: cat,
                        isSelected: activeCategory == cat
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            activeCategory = cat
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pose grid

    private var poseGrid: some View {
        ScrollView(showsIndicators: false) {
            let columns = [
                GridItem(.flexible(), spacing: EcrinSpacing.sm),
                GridItem(.flexible(), spacing: EcrinSpacing.sm),
                GridItem(.flexible(), spacing: EcrinSpacing.sm)
            ]
            LazyVGrid(columns: columns, spacing: EcrinSpacing.sm) {
                ForEach(posesForActiveCategory) { pose in
                    PoseCard(
                        pose: pose,
                        selectionIndex: vm.selectionIndex(of: pose),
                        isDisabled: !vm.canAddPose(pose) && !vm.isSelected(pose)
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            vm.togglePose(pose)
                        }
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.md)
        }
        .frame(maxHeight: 280)
    }

    // MARK: - Selection strip (reorderable)

    private var selectionStrip: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
            HStack {
                Text("VUES SÉLECTIONNÉES")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
                Spacer()
                Text("Appui long pour réordonner")
                    .font(.system(size: 9))
                    .foregroundStyle(EcrinColor.textMuted.opacity(0.6))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(Array(vm.selectedPoses.enumerated()), id: \.element.id) { index, pose in
                        SelectedPoseChip(index: index + 1, pose: pose) {
                            withAnimation(EcrinAnimation.springSnap) {
                                vm.togglePose(pose)
                            }
                        }
                    }
                }
            }
        }
        .padding(EcrinSpacing.md)
        .background(EcrinColor.glassFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        }
    }

    // MARK: - Counter badge

    private var counterBadge: some View {
        HStack(spacing: EcrinSpacing.xs) {
            ForEach(0..<MultiPoseViewModel.maxPoses, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < vm.selectedPoses.count ? EcrinColor.gold : EcrinColor.glassStroke)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                    .animation(EcrinAnimation.springSnap, value: vm.selectedPoses.count)
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }
}

// MARK: - CategoryTab

private struct CategoryTab: View {
    let category: PoseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(category.rawValue)
                    .font(EcrinFont.caption)
            }
            .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background(
                isSelected ? EcrinColor.gold.opacity(0.12) : EcrinColor.glassFill,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? EcrinColor.gold.opacity(0.5) : EcrinColor.glassStroke,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PoseCard

struct PoseCard: View {
    let pose: PoseVariant
    let selectionIndex: Int?
    let isDisabled: Bool
    let onTap: () -> Void

    private var isSelected: Bool { selectionIndex != nil }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: EcrinSpacing.sm) {
                    poseIllustration
                        .frame(height: 56)

                    Text(pose.name)
                        .font(EcrinFont.caption)
                        .foregroundStyle(
                            isDisabled
                                ? EcrinColor.textMuted
                                : isSelected ? EcrinColor.textPrimary : EcrinColor.textSecondary
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if pose.isMotion {
                        Text("Mouvement")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(EcrinColor.gold.opacity(0.7))
                            .kerning(1)
                    }
                }
                .padding(.vertical, EcrinSpacing.sm)
                .padding(.horizontal, EcrinSpacing.xs)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? EcrinColor.gold.opacity(0.08)
                        : isDisabled ? EcrinColor.glassFill.opacity(0.5) : EcrinColor.glassFill,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                            lineWidth: isSelected ? 1.2 : 0.5
                        )
                }
                .opacity(isDisabled ? 0.45 : 1.0)

                // Badge numéro de sélection
                if let index = selectionIndex {
                    selectionBadge(number: index + 1)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }

    // MARK: - Pose illustration

    private var poseIllustration: some View {
        ZStack {
            Circle()
                .fill(
                    isSelected
                        ? EcrinColor.gold.opacity(0.15)
                        : EcrinColor.glassFill.opacity(0.8)
                )
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? EcrinColor.gold.opacity(0.4) : EcrinColor.glassStroke,
                            lineWidth: 0.5
                        )
                }

            Image(systemName: pose.icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(
                    isDisabled
                        ? EcrinColor.textMuted
                        : isSelected ? EcrinColor.gold : EcrinColor.textSecondary
                )
        }
    }

    private func selectionBadge(number: Int) -> some View {
        ZStack {
            Circle()
                .fill(EcrinColor.gold)
                .frame(width: 20, height: 20)
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(EcrinColor.background)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - SelectedPoseChip

private struct SelectedPoseChip: View {
    let index: Int
    let pose: PoseVariant
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(EcrinColor.gold)
                    .frame(width: 16, height: 16)
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(EcrinColor.background)
            }

            Image(systemName: pose.icon)
                .font(.system(size: 10))
                .foregroundStyle(EcrinColor.gold)

            Text(pose.name)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(EcrinColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EcrinSpacing.sm)
        .padding(.vertical, 6)
        .background(EcrinColor.gold.opacity(0.1), in: Capsule())
        .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 0.5))
        .transition(.scale.combined(with: .opacity))
    }
}
