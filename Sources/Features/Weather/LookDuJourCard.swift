import SwiftUI
import UIKit

// MARK: - LookDuJourCard

struct LookDuJourCard: View {
    @Bindable var viewModel: LookDuJourViewModel
    @Environment(AppState.self) private var appState
    @Environment(LocationService.self) private var locationService
    @Environment(ClothingCatalogService.self) private var catalogService

    var onTryLook: (LookRecommendation) -> Void
    var onOpenCatalog: () -> Void

    @State private var manualCity = ""
    @State private var cardAppeared = false

    var body: some View {
        GlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                headerRow
                content
                    .animation(.easeInOut(duration: 0.35), value: viewModel.displayStateKey)
            }
            .padding(EcrinSpacing.lg)
            .background { weatherGradient }
        }
        .refreshable {
            await viewModel.refresh(appState: appState, force: true)
        }
        .alert("Localisation pour votre look", isPresented: $viewModel.showLocationPreAlert) {
            Button(L10n.WeatherUI.continueAction) {
                Task { await viewModel.confirmLocationPermission(appState: appState) }
            }
            Button(L10n.WeatherUI.enterMyCity) {
                viewModel.showLocationPreAlert = false
                viewModel.showCitySearch = true
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(
                L10n.WeatherUI.locationPrivacyNotice
            )
        }
        .sheet(isPresented: $viewModel.showGenderPicker) {
            GenderPickerSheet { gender in
                Task { await viewModel.setGender(gender, appState: appState) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showBudgetPicker) {
            BudgetPickerSheet(
                selectedBudget: viewModel.maxBudget,
                tiers: LookDuJourViewModel.budgetTiers
            ) { budget in
                Task { await viewModel.setBudget(budget, appState: appState) }
            }
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $viewModel.showCitySearch) {
            CitySearchSheet(
                cityText: $manualCity,
                isLoading: locationService.isLocating,
                errorMessage: locationService.lastError,
                onSubmit: {
                    Task { await viewModel.applyManualCity(manualCity, appState: appState) }
                }
            )
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.LookOfDay.title)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                if viewModel.showConversionMessage {
                    Text(L10n.LookOfDay.tagline)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(8))
                                viewModel.dismissConversionMessage()
                            }
                        }
                }
            }
            Spacer(minLength: 8)
            if case .loading = viewModel.displayState {
                ProgressView()
                    .tint(EcrinColor.gold)
            } else if viewModel.hasActivated {
                // Budget filter
                Button {
                    viewModel.showBudgetPicker = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 11, weight: .medium))
                        if let budget = viewModel.maxBudget {
                            Text("\(Int(budget))€")
                                .font(EcrinFont.label)
                        }
                    }
                    .foregroundStyle(viewModel.maxBudget != nil ? EcrinColor.gold : EcrinColor.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.maxBudget != nil
                    ? "Filtre budget : \(Int(viewModel.maxBudget!))€" : "Filtrer par budget")

                // Toggle notification quotidienne
                Button {
                    viewModel.toggleDailyNotification()
                } label: {
                    Image(systemName: viewModel.dailyNotificationEnabled
                          ? "bell.fill" : "bell.slash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(viewModel.dailyNotificationEnabled
                            ? EcrinColor.gold : EcrinColor.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.dailyNotificationEnabled
                    ? "Désactiver le rappel quotidien" : "Activer le rappel 8h")

                Button {
                    Task { await viewModel.refresh(appState: appState, force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(EcrinColor.gold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.WeatherUI.refreshLook)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.displayState {
        case .idle:
            idleContent
        case .loading:
            loadingContent
        case .ready(let look), .stale(let look, _):
            readyContent(look)
        case .needsGender:
            needsGenderContent
        case .catalogEmpty:
            Text(L10n.LookOfDay.catalogLoading)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
        case .offline:
            offlineContent
        case .error(let message):
            errorContent(message)
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            Text(L10n.LookOfDay.discover)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textSecondary)
            GoldButton(title: L10n.LookOfDay.seeMyLook) {
                Task { await viewModel.onCardTapped(appState: appState) }
            }
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            // Shimmer skeleton — premium loading feel
            ForEach(0..<3, id: \.self) { i in
                ShimmerRect(width: [180, 140, 100][i], height: 12)
            }
            HStack(spacing: EcrinSpacing.sm) {
                ShimmerRect(width: 120, height: 80, cornerRadius: 14)
                VStack(spacing: EcrinSpacing.sm) {
                    ShimmerRect(width: nil, height: 36, cornerRadius: 8)
                    ShimmerRect(width: nil, height: 36, cornerRadius: 8)
                }
            }
            HStack(spacing: EcrinSpacing.sm) {
                ProgressView()
                    .tint(EcrinColor.gold)
                Text(L10n.LookOfDay.analyzing)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readyContent(_ look: LookRecommendation) -> some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            HStack {
                WeatherBadge(snapshot: look.weather)
                    .transition(.scale.combined(with: .opacity))
                Spacer()
                if case .stale(_, let badge) = viewModel.displayState {
                    Text(badge)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
            .opacity(cardAppeared ? 1 : 0)
            .offset(y: cardAppeared ? 0 : 8)

            if let badge = locationService.defaultLocationBadge {
                Text(badge)
                    .font(.system(size: 10))
                    .foregroundStyle(EcrinColor.textSecondary)  // WCAG AA ≥ 4.5:1
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\"\(look.headline)\"")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text(look.subline)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineLimit(2)
                Text(look.styleTag)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.gold.opacity(0.85))
            }
            .opacity(cardAppeared ? 1 : 0)
            .offset(y: cardAppeared ? 0 : 12)

            lookVisual(look)
                .opacity(cardAppeared ? 1 : 0)
                .offset(y: cardAppeared ? 0 : 16)

            HStack(spacing: EcrinSpacing.sm) {
                GoldButton(title: L10n.LookOfDay.tryButton, flexible: true) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTryLook(look)
                }
                GhostButton(title: L10n.LookOfDay.catalogButton, flexible: true) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onOpenCatalog()
                }
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    viewModel.toggleSave(look: look)
                } label: {
                    Image(systemName: viewModel.currentLookSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(viewModel.currentLookSaved ? EcrinColor.gold : EcrinColor.textSecondary)
                        .frame(width: 38, height: 38)
                        .glassCircleButton(active: viewModel.currentLookSaved)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.currentLookSaved
                    ? "Look déjà sauvegardé"
                    : "Sauvegarder ce look")
            }
            .opacity(cardAppeared ? 1 : 0)
            .offset(y: cardAppeared ? 0 : 20)
        }
        .onAppear {
            withAnimation(EcrinAnimation.glassReveal.delay(0.1)) {
                cardAppeared = true
            }
        }
        .onDisappear { cardAppeared = false }
    }

    private var needsGenderContent: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            Text(L10n.LookOfDay.chooseGender)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
            GoldButton(title: L10n.LookOfDay.genderCTA) {
                viewModel.showGenderPicker = true
            }
        }
    }

    private var offlineContent: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text(L10n.LookOfDay.offline)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
            GhostButton(title: L10n.Common.retry) {
                Task { await viewModel.refresh(appState: appState, force: true) }
            }
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text(message)
                .font(EcrinFont.caption)
                .foregroundStyle(.orange)
            HStack(spacing: EcrinSpacing.sm) {
                GhostButton(title: L10n.Common.retry) {
                    Task { await viewModel.refresh(appState: appState, force: true) }
                }
                if locationService.authStatus == .denied || locationService.authStatus == .restricted {
                    GhostButton(title: L10n.LookOfDay.myCity) {
                        viewModel.showCitySearch = true
                    }
                }
            }
        }
    }

    // MARK: - Look visuel (layout lookbook)

    @ViewBuilder
    private func lookVisual(_ look: LookRecommendation) -> some View {
        let catalogItems = look.items
        // Bijoux garde-robe identifiés (affichés séparément avec badge)
        let jewelryWardrobeItems = look.wardrobeItems.filter { $0.category.group == .jewelry }
        // Articles habillement garde-robe (haut, bas, chaussures)
        let clothingWardrobeItems = look.wardrobeItems.filter { $0.category.group != .jewelry }

        if catalogItems.isEmpty && clothingWardrobeItems.isEmpty {
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: "tshirt.fill")
                    .foregroundStyle(EcrinColor.textMuted)
                Text(L10n.LookOfDay.noOutfit)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }
            .padding(.vertical, EcrinSpacing.sm)
        } else {
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                HStack(alignment: .top, spacing: EcrinSpacing.sm) {
                    // Hero : on privilégie un visuel avec image —
                    // un wardrobe item AVEC photo, sinon catalogue, sinon wardrobe sans photo.
                    let wardrobeWithImage = clothingWardrobeItems.first { $0.imageURL != nil || $0.userPhotoData != nil }
                    if let w = wardrobeWithImage {
                        LookHeroWardrobeImage(item: w)
                    } else if let firstCatalog = catalogItems.first {
                        LookHeroImage(item: firstCatalog)
                    } else if let firstWardrobe = clothingWardrobeItems.first {
                        LookHeroWardrobeImage(item: firstWardrobe)
                    }

                    // Colonne secondaire
                    VStack(spacing: EcrinSpacing.sm) {
                        let secondaryWardrobe = clothingWardrobeItems.dropFirst()
                        let secondaryCatalog = catalogItems.dropFirst()
                        let allSecondary: [QuickTryOnItem] = secondaryWardrobe.prefix(2).map { .wardrobe($0) }
                            + (clothingWardrobeItems.isEmpty ? [] : secondaryCatalog.prefix(1).map { .catalog($0) })
                            + (clothingWardrobeItems.isEmpty ? secondaryCatalog.prefix(2).map { .catalog($0) } : [])

                        ForEach(Array(allSecondary.prefix(2).enumerated()), id: \.offset) { _, anyItem in
                            switch anyItem {
                            case .wardrobe(let fi):
                                LookSecondaryWardrobeImage(item: fi)
                            case .catalog(let ci):
                                LookSecondaryImage(item: ci)
                            }
                        }

                        let totalCatalog = catalogItems.count + (clothingWardrobeItems.isEmpty ? 0 : 1)
                        if totalCatalog > 3 {
                            Text("+\(totalCatalog - 3)")
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.gold)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Ligne bijoux garde-robe (slot bijou)
                if !jewelryWardrobeItems.isEmpty {
                    HStack(spacing: EcrinSpacing.xs) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(EcrinColor.gold)
                        Text(L10n.LookOfDay.yourJewelry(jewelryWardrobeItems.map(\.name).joined(separator: ", ")))
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.gold.opacity(0.9))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(EcrinColor.gold.opacity(0.1), in: Capsule())
                }
            }
        }
    }

    private var weatherGradient: some View {
        LinearGradient(
            colors: gradientColorsForCurrentState(),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(EcrinAnimation.glassReveal, value: viewModel.displayStateKey)
    }

    private func gradientColorsForCurrentState() -> [Color] {
        switch viewModel.displayState {
        case .ready(let look), .stale(let look, _):
            return gradientColors(for: look.weather.condition)
        default:
            return [EcrinColor.gold.opacity(0.06), Color.clear]
        }
    }

    private func gradientColors(for condition: WeatherCondition) -> [Color] {
        switch condition {
        case .clearSky:
            return [Color(hex: "#F59E0B").opacity(0.12), Color.clear]
        case .rain, .drizzle, .thunderstorm:
            return [Color(hex: "#64748B").opacity(0.2), Color.clear]
        case .snow:
            return [Color(hex: "#E2E8F0").opacity(0.15), Color.clear]
        default:
            return [EcrinColor.gold.opacity(0.08), Color.clear]
        }
    }
}

// MARK: - Shimmer Loading Rectangle

private struct ShimmerRect: View {
    let width: CGFloat?
    let height: CGFloat
    var cornerRadius: CGFloat = 6

    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(EcrinColor.surface)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        colors: [
                            Color.clear,
                            EcrinColor.gold.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.6)
                    .offset(x: shimmerPhase * w)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = 1.5
                }
            }
    }
}

// MARK: - LookHeroImage — article principal en grand format

private struct LookHeroImage: View {
    let item: CatalogClothingItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(EcrinColor.surface)

            if let url = item.displayImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        // Vignette hero 120×160 — scaledToFill pour effet "magazine cover"
                        // (la zone est trop petite pour scaledToFit + barres noires)
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: item.categoryIcon)
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                Image(systemName: item.categoryIcon)
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(EcrinColor.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Label nom en bas
            Text(item.name)
                .font(EcrinFont.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(width: 120, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        }
    }
}

// MARK: - LookSecondaryImage — articles secondaires

private struct LookSecondaryImage: View {
    let item: CatalogClothingItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(EcrinColor.surface)

            if let url = item.displayImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: item.categoryIcon)
                            .font(.system(size: 18, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
            } else {
                Image(systemName: item.categoryIcon)
                    .font(.system(size: 18, weight: .thin))
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        }
    }
}

// MARK: - LookHeroWardrobeImage — article garde-robe principal (hero)

private struct LookHeroWardrobeImage: View {
    let item: FashionItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(EcrinColor.surface)

            // Vignette hero 120×160 — scaledToFill pour effet "magazine cover"
            if let data = item.userPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if let url = item.displayImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: item.category.icon)
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                Image(systemName: item.category.icon)
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(EcrinColor.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Badge "Ma garde-robe"
                Label(L10n.WeatherUI.myWardrobe, systemImage: "checkmark.seal.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.black.opacity(0.6), in: Capsule())
                Text(item.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(.white).lineLimit(2)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.black.opacity(0.7), Color.clear], startPoint: .bottom, endPoint: .top)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(width: 120, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(EcrinColor.gold.opacity(0.5), lineWidth: 1)
        }
    }
}

// MARK: - LookSecondaryWardrobeImage — article garde-robe secondaire

private struct LookSecondaryWardrobeImage: View {
    let item: FashionItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(EcrinColor.surface)

            if let data = item.userPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if let url = item.displayImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default:
                        Image(systemName: item.category.icon)
                            .font(.system(size: 18, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
            } else {
                Image(systemName: item.category.icon)
                    .font(.system(size: 18, weight: .thin))
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(EcrinColor.gold.opacity(0.5), lineWidth: 1)
        }
    }
}

// MARK: - LookItemThumb (conservé pour usage futur)

private struct LookItemThumb: View {
    let item: CatalogClothingItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(EcrinColor.surface)
            if let url = item.displayImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: item.categoryIcon)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
            } else {
                Image(systemName: item.categoryIcon)
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
        .frame(width: 56, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
