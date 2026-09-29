import SwiftUI
import PhotosUI

// MARK: - ShoesTryOnView

struct ShoesTryOnView: View {
    var preselectedItem: FashionItem?

    @State private var vm = ShoesTryOnViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var selectedShoe: FashionItem?
    @State private var showPaywall = false

    // Shoes from wardrobe (loaded from storage)
    @State private var wardrobeVM = WardrobeViewModel()

    private var shoesItems: [FashionItem] {
        wardrobeVM.items.filter { $0.category.group == .shoes }
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.lg) {
                    // Header
                    if preselectedItem == nil {
                        header
                            .padding(.horizontal, EcrinSpacing.lg)
                            .padding(.top, EcrinSpacing.md)
                    }

                    photoModeSection

                    // Sélecteur chaussures
                    VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                        sectionLabel(L10n.WardrobeUI.chooseShoe, icon: "shoe.fill")
                            .padding(.horizontal, EcrinSpacing.lg)

                        if let preset = preselectedItem {
                            preselectShoeCard(preset)
                                .padding(.horizontal, EcrinSpacing.lg)
                                .onAppear { selectedShoe = preset }
                        } else if shoesItems.isEmpty {
                            emptyShoesCTA
                                .padding(.horizontal, EcrinSpacing.lg)
                        } else {
                            shoesScroll
                        }
                    }

                    // Angle selector
                    VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                        sectionLabel(L10n.WardrobeUI.shootingAngle, icon: "arrow.triangle.2.circlepath.camera")
                            .padding(.horizontal, EcrinSpacing.lg)

                        AngleSelectorRow(selected: $vm.selectedAngle)
                            .padding(.horizontal, EcrinSpacing.lg)
                    }

                    // Result
                    if let result = vm.result {
                        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                            sectionLabel(L10n.WardrobeUI.resultCaps, icon: "sparkles")
                                .padding(.horizontal, EcrinSpacing.lg)

                            ResultCarousel(images: result)
                                .padding(.leading, EcrinSpacing.lg)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // CTA
                    ctaButton
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.bottom, EcrinSpacing.xxl)
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task { await vm.loadPhoto(from: item) }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Photo Mode Section (Gemini IA)

    private var photoModeSection: some View {
        VStack(spacing: EcrinSpacing.lg) {
            // Info Gemini IA
            GlassCard(cornerRadius: 16) {
                HStack(spacing: EcrinSpacing.md) {
                    Image(systemName: "shoe.2.fill")
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(EcrinColor.gold)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.WardrobeUI.geminiFlashShoes)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textPrimary)
                        Text(L10n.WardrobeUI.geminiImageInfo)
                            .font(.system(size: 11))
                            .foregroundStyle(EcrinColor.textMuted)
                            .lineSpacing(3)
                    }
                }
                .padding(EcrinSpacing.md)
            }
            .padding(.horizontal, EcrinSpacing.lg)

            // Photo zone pieds
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                sectionLabel(L10n.WardrobeUI.yourPhotoCaps, icon: "camera.fill")
                    .padding(.horizontal, EcrinSpacing.lg)
                footPhotoZone
                footTips.padding(.horizontal, EcrinSpacing.lg)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.WardrobeUI.tryOnCaps)
                    .font(EcrinFont.label).kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(L10n.ClothingCategories.shoes)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
            Spacer()
            TrialBadge(remaining: vm.trialsRemaining)
        }
    }

    // MARK: - Foot Photo Zone

    private var footPhotoZone: some View {
        Button { showPhotoPicker = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(EcrinColor.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                vm.userPhoto != nil ? EcrinColor.gold.opacity(0.3) : EcrinColor.glassStroke,
                                style: StrokeStyle(
                                    lineWidth: 1,
                                    dash: vm.userPhoto != nil ? [] : [6]
                                )
                            )
                    }

                if let photo = vm.userPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if vm.isGenerating {
                        ZStack {
                            Color.black.opacity(0.5)
                            VStack(spacing: EcrinSpacing.sm) {
                                ProgressView()
                                    .tint(EcrinColor.gold)
                                    .scaleEffect(1.5)
                                Text(L10n.WardrobeUI.tryOnInProgress)
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textSecondary)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                } else {
                    VStack(spacing: EcrinSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(EcrinColor.gold.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "shoe.2.fill")
                                .font(.system(size: 32, weight: .thin))
                                .foregroundStyle(EcrinColor.gold.opacity(0.7))
                        }

                        VStack(spacing: EcrinSpacing.sm) {
                            Text(L10n.WardrobeUI.photographYourFeet)
                                .font(EcrinFont.body)
                                .foregroundStyle(EcrinColor.textPrimary)
                            Text(L10n.WardrobeUI.fromFrontOrSide)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                    }
                }
            }
            .frame(height: 300)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, EcrinSpacing.lg)
    }

    // MARK: - Foot Tips

    private var footTips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(ShoesTip.allCases, id: \.self) { tip in
                    TipChip(tip: tip)
                }
            }
        }
    }

    // MARK: - Shoes Scroll

    private var shoesScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.md) {
                ForEach(shoesItems) { shoe in
                    ShoeThumb(
                        shoe: shoe,
                        isSelected: selectedShoe?.id == shoe.id
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            selectedShoe = shoe
                        }
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - Preselect card

    private func preselectShoeCard(_ shoe: FashionItem) -> some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: EcrinSpacing.md) {
                ZStack {
                    Circle()
                        .fill(FashionGroup.shoes.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: shoe.category.icon)
                        .font(.system(size: 22, weight: .thin))
                        .foregroundStyle(FashionGroup.shoes.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(shoe.name)
                        .font(EcrinFont.body).foregroundStyle(EcrinColor.textPrimary)
                    if let brand = shoe.brand {
                        Text(brand)
                            .font(EcrinFont.caption).foregroundStyle(EcrinColor.textSecondary)
                    }
                    Text(shoe.category.rawValue)
                        .font(EcrinFont.caption).foregroundStyle(FashionGroup.shoes.color)
                }
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(EcrinColor.gold)
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Empty shoes

    private var emptyShoesCTA: some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: EcrinSpacing.md) {
                Image(systemName: "shoe.fill")
                    .font(.system(size: 20, weight: .thin))
                    .foregroundStyle(FashionGroup.shoes.color.opacity(0.6))
                Text(L10n.WardrobeUI.addShoesToTry)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        GoldButton(title: vm.isGenerating ? L10n.CommonUI.generating : L10n.WardrobeUI.tryTheseShoes) {
            guard let shoe = selectedShoe else { return }
            Task {
                await vm.generate(item: shoe, showPaywall: { showPaywall = true })
            }
        }
        .disabled(vm.userPhoto == nil || selectedShoe == nil || vm.isGenerating)
        .opacity((vm.userPhoto == nil || selectedShoe == nil) ? 0.4 : 1)
    }

    // MARK: - Section label helper

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .kerning(2)
        }
        .font(EcrinFont.label)
        .foregroundStyle(EcrinColor.textMuted)
    }
}

// MARK: - ShoesTip

enum ShoesTip: CaseIterable {
    case lighting, background, angle, socks

    var icon: String {
        switch self {
        case .lighting:    return "sun.max.fill"
        case .background:  return "rectangle.fill"
        case .angle:       return "camera.viewfinder"
        case .socks:       return "figure.walk"
        }
    }

    var text: String {
        switch self {
        case .lighting:   return "Bon éclairage"
        case .background: return "Fond neutre"
        case .angle:      return "Vue de face ou côté"
        case .socks:      return "Chaussettes ton peau"
        }
    }
}

private struct TipChip: View {
    let tip: ShoesTip

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: tip.icon)
                .font(.system(size: 10))
                .foregroundStyle(EcrinColor.gold)
            Text(tip.text)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, 7)
        .background(EcrinColor.glassFill)
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        }
    }
}

// MARK: - Angle Selector

private struct AngleSelectorRow: View {
    @Binding var selected: ShootingAngle

    var body: some View {
        HStack(spacing: EcrinSpacing.sm) {
            ForEach(ShootingAngle.allCases, id: \.self) { angle in
                Button {
                    withAnimation(EcrinAnimation.springSnap) { selected = angle }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: angle.icon)
                            .font(.system(size: 10))
                        Text(angle.rawValue)
                            .font(EcrinFont.caption)
                    }
                    .foregroundStyle(selected == angle ? EcrinColor.background : EcrinColor.textSecondary)
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, 8)
                    .background(selected == angle ? EcrinColor.gold : EcrinColor.glassFill)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(EcrinAnimation.springSnap, value: selected)
            }
        }
    }
}

// MARK: - Shoe Thumb

private struct ShoeThumb: View {
    let shoe: FashionItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: EcrinSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? FashionGroup.shoes.color.opacity(0.15) : EcrinColor.glassFill)
                        .frame(width: 80, height: 80)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                                    lineWidth: isSelected ? 1 : 0.5
                                )
                        }

                    if let img = WardrobePhotoStore.shared.image(for: shoe.id) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: shoe.category.icon)
                            .font(.system(size: 28, weight: .thin))
                            .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                    }
                }

                Text(shoe.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(isSelected ? EcrinColor.textPrimary : EcrinColor.textMuted)
                    .lineLimit(1)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - ShoesTryOnViewModel

@MainActor
final class ShoesTryOnViewModel: ObservableObject {
    @Published var userPhoto: UIImage?
    @Published var result: [UIImage]?
    @Published var isGenerating = false
    @Published var selectedAngle: ShootingAngle = .front
    @Published var errorMessage: String?

    var trialsRemaining: Int { CreditsManager.shared.remaining }

    private let imageService = ImageGenerationService.shared

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        userPhoto = image
        result = nil
    }

    func generate(item: FashionItem, showPaywall: () -> Void) async {
        guard CreditsManager.shared.consume(showPaywall: showPaywall) else { return }
        guard let photo = userPhoto else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let generated = try await imageService.tryOnFashion(photo: photo, item: item, angle: selectedAngle)
            result = [generated]
            CreditsManager.shared.syncDetached()
        } catch {
            CreditsManager.shared.remaining += 1
            errorMessage = error.localizedDescription
        }
    }
}
