import SwiftUI

// MARK: - Frame Picker Sheet

struct FramePickerView: View {
    @ObservedObject var viewModel: FrameViewModel
    let tryOnImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    @Namespace private var categoryNamespace
    @State private var showCustomizer = false

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                sheetHeader

                // Live preview (top 40% of sheet)
                livePreview
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)

                // Category tabs
                categoryTabs

                Divider()
                    .background(EcrinColor.glassStroke)

                // Frame grid
                ScrollView(showsIndicators: false) {
                    frameGrid
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.vertical, EcrinSpacing.md)
                }

                // Bottom bar
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCustomizer) {
            if let selected = viewModel.selectedFrame {
                FrameCustomizerView(frame: selected) { updated in
                    viewModel.applyCustomFrame(updated)
                }
            }
        }
    }

    // MARK: Header
    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("SNAPSHOT FRAME")
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text("Cadres artistiques L99")
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(EcrinColor.glassFill)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, EcrinSpacing.lg)
        .padding(.bottom, EcrinSpacing.sm)
    }

    // MARK: Live Preview
    private var livePreview: some View {
        GeometryReader { geo in
            let previewH = geo.size.height
            let previewW = previewH * 0.75

            ZStack {
                // Try-on image
                if let img = tryOnImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: previewW, height: previewH)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(EcrinColor.glassFill)
                        .frame(width: previewW, height: previewH)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32, weight: .thin))
                                .foregroundStyle(EcrinColor.textMuted)
                        )
                }

                // Frame overlay (SwiftUI)
                if let frame = viewModel.selectedFrame {
                    FrameSwiftUIView(frame: frame, size: CGSize(width: previewW, height: previewH))
                }
            }
            .frame(width: previewW, height: previewH)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: EcrinColor.gold.opacity(viewModel.selectedFrame != nil ? 0.2 : 0), radius: 16, x: 0, y: 8)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 240)
    }

    // MARK: Category Tabs
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(FrameCategory.allCases) { cat in
                    categoryTab(cat)
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.vertical, EcrinSpacing.sm)
        }
    }

    private func categoryTab(_ cat: FrameCategory) -> some View {
        let isSelected = viewModel.selectedCategory == cat
        return Button {
            withAnimation(EcrinAnimation.springSnap) {
                viewModel.selectedCategory = cat
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: cat.icon)
                    .font(.system(size: 11))
                Text(cat.rawValue)
                    .font(EcrinFont.cta)
                    .kerning(0.8)
            }
            .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(EcrinColor.gold)
                        .matchedGeometryEffect(id: "frameCatTab", in: categoryNamespace)
                } else {
                    Capsule().fill(EcrinColor.glassFill)
                }
            }
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : EcrinColor.glassStroke,
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Frame Grid
    private var frameGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: EcrinSpacing.md) {
            ForEach(viewModel.filteredFrames) { item in
                VStack(spacing: 5) {
                    FramePreviewTile(
                        frame: item,
                        isSelected: viewModel.selectedFrame?.id == item.id,
                        lockLabel: viewModel.lockLabel(item)
                    )
                    Text(item.name)
                        .font(.system(size: 9, weight: .medium))
                        .kerning(0.3)
                        .foregroundStyle(
                            viewModel.selectedFrame?.id == item.id
                            ? EcrinColor.gold
                            : EcrinColor.textMuted
                        )
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .onTapGesture {
                    if viewModel.isUnlocked(item) {
                        viewModel.select(item)
                    }
                }
            }
        }
    }

    // MARK: Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: EcrinSpacing.sm) {
            if viewModel.selectedFrame != nil {
                Button {
                    showCustomizer = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13))
                        Text("Personnaliser")
                            .font(EcrinFont.cta)
                            .kerning(1.5)
                    }
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, EcrinSpacing.xl)
                    .padding(.vertical, EcrinSpacing.sm)
                    .overlay(
                        Capsule().strokeBorder(EcrinColor.gold.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: EcrinSpacing.md) {
                GhostButton(title: "Sans cadre") {
                    viewModel.clearFrame()
                    dismiss()
                }
                GoldButton(title: L10n.Common.apply) {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
        .background {
            Rectangle()
                .fill(Color(hex: "#0A0A0C").opacity(0.97))
                .overlay(Rectangle().frame(height: 0.5).foregroundStyle(EcrinColor.glassStroke), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Frame ViewModel

@MainActor
final class FrameViewModel: ObservableObject {
    @Published var frames: [SnapshotFrame] = SnapshotFrame.catalog
    @Published var selectedFrame: SnapshotFrame?
    @Published var selectedCategory: FrameCategory = .classic
    @Published var unlockedByUser: Set<String> = []
    @Published var isRendering = false

    /// Set to true when the user has an active paid subscription.
    /// Pragmatic default: premium frames (isPremium=true, isUnlockableByXP=false) are
    /// unlocked for subscribers via CreditsManager.shared.isUnlimited OR
    /// AppState.subscription.isSubscribed.  Caller sets this after init.
    var isPremiumUser: Bool = false

    var filteredFrames: [SnapshotFrame] {
        frames.filter { $0.category == selectedCategory }
    }

    func isUnlocked(_ frame: SnapshotFrame) -> Bool {
        // Free frames — always accessible.
        if !frame.isPremium && !frame.isUnlockableByXP { return true }
        // XP-unlockable frames — regardless of subscription tier.
        if frame.isUnlockableByXP { return unlockedByUser.contains(frame.id) }
        // Premium-only frames (isPremium=true, isUnlockableByXP=false):
        // unlocked when the user holds an active paid subscription.
        if frame.isPremium && !frame.isUnlockableByXP { return isPremiumUser }
        return false
    }

    func lockLabel(_ frame: SnapshotFrame) -> String? {
        if frame.isPremium && !frame.isUnlockableByXP && !isPremiumUser { return "Premium" }
        if frame.isUnlockableByXP && !unlockedByUser.contains(frame.id) {
            return "\(frame.xpRequired) XP"
        }
        return nil
    }

    func select(_ frame: SnapshotFrame) {
        guard isUnlocked(frame) else { return }
        withAnimation(EcrinAnimation.springSnap) {
            selectedFrame = frame
        }
    }

    func clearFrame() {
        withAnimation(EcrinAnimation.springSnap) {
            selectedFrame = nil
        }
    }

    func applyCustomFrame(_ updated: SnapshotFrame) {
        selectedFrame = updated
        if let idx = frames.firstIndex(where: { $0.id == updated.id }) {
            frames[idx] = updated
        }
    }
}
