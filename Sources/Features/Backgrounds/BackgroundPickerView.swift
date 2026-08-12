import SwiftUI
import PhotosUI

// MARK: - Background Picker Sheet

struct BackgroundPickerView: View {
    @ObservedObject var viewModel: BackgroundViewModel
    let tryOnImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    @State private var photosItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @Namespace private var categoryNamespace

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                sheetHeader

                // Category tabs
                categoryTabs

                Divider()
                    .background(EcrinColor.glassStroke)
                    .padding(.top, EcrinSpacing.sm)

                // Background grid
                ScrollView(showsIndicators: false) {
                    VStack(spacing: EcrinSpacing.lg) {
                        // Live mini preview
                        if let bg = viewModel.selectedBackground {
                            miniPreview(bg: bg)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }

                        // Custom photo row
                        if viewModel.selectedCategory == .custom {
                            customPhotoRow
                        }

                        // Grid
                        backgroundGrid
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.lg)
                }

                // Bottom CTA
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .photosPicker(isPresented: $showPhotosPicker, selection: $photosItem, matching: .images)
        .onChange(of: photosItem) { _, item in
            Task {
                if let item, let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.setUserPhoto(data)
                    withAnimation { viewModel.selectedCategory = .custom }
                }
            }
        }
    }

    // MARK: Header
    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.BackgroundsUI.backgroundCaps)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(L10n.BackgroundsUI.chooseBackdrop)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
            Spacer()
            Button(action: { dismiss() }) {
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
        .padding(.bottom, EcrinSpacing.md)
    }

    // MARK: Category Tabs
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(BackgroundCategory.allCases) { cat in
                    categoryTab(cat)
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.vertical, EcrinSpacing.sm)
        }
    }

    private func categoryTab(_ cat: BackgroundCategory) -> some View {
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
                        .matchedGeometryEffect(id: "catTab", in: categoryNamespace)
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

    // MARK: Mini Live Preview
    private func miniPreview(bg: BackgroundItem) -> some View {
        ZStack(alignment: .center) {
            // Background swatch
            BackgroundSwatchView(item: bg, cornerRadius: 16)
                .frame(height: 120)

            // Try-on image overlay
            if let img = tryOnImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            }

            // Name label
            VStack {
                Spacer()
                HStack {
                    Text(bg.name)
                        .font(EcrinFont.caption)
                        .kerning(1)
                        .foregroundStyle(EcrinColor.ivory)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                    Spacer()
                    // Remove bg
                    Button {
                        viewModel.clearBackground()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(EcrinColor.gold.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: EcrinColor.gold.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    // MARK: Custom Photo Row
    private var customPhotoRow: some View {
        Button {
            showPhotosPicker = true
        } label: {
            HStack(spacing: EcrinSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(EcrinColor.glassFill)
                        .frame(width: 80, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(EcrinColor.gold.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 22, weight: .thin))
                        .foregroundStyle(EcrinColor.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.BackgroundsUI.myPersonalBackground)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(L10n.BackgroundsUI.usePhotoAsBackdrop)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(EcrinSpacing.md)
            .background(EcrinColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Background Grid
    private var backgroundGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: EcrinSpacing.md) {
            ForEach(viewModel.filteredBackgrounds) { item in
                VStack(spacing: 5) {
                    BackgroundPreviewTile(
                        item: item,
                        isSelected: viewModel.selectedBackground?.id == item.id,
                        lockLabel: viewModel.lockLabel(item)
                    )
                    Text(item.name)
                        .font(.system(size: 9, weight: .medium))
                        .kerning(0.3)
                        .foregroundStyle(
                            viewModel.selectedBackground?.id == item.id
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
        HStack(spacing: EcrinSpacing.md) {
            GhostButton(title: L10n.BackgroundsUI.noBackground) {
                viewModel.clearBackground()
                dismiss()
            }
            GoldButton(title: L10n.Common.apply) {
                dismiss()
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
        .background {
            Rectangle()
                .fill(Color(hex: "#0A0A0C").opacity(0.97))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(EcrinColor.glassStroke),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
