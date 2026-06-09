import SwiftUI

// MARK: - MultiPoseResultView

struct MultiPoseResultView: View {
    let results: [MultiPoseViewModel.PoseResult]
    let item: QuickTryOnItem

    var onSaveToDressing: (() -> Void)?
    var onClose: (() -> Void)?

    @State private var displayMode: DisplayMode = .grid
    @State private var selectedIndex: Int = 0
    @State private var fullScreenResult: MultiPoseViewModel.PoseResult? = nil
    @State private var showShareSheet: Bool = false
    @State private var shareImages: [UIImage] = []

    enum DisplayMode {
        case grid
        case carousel
    }

    private var doneResults: [MultiPoseViewModel.PoseResult] {
        results.filter { $0.state == .done && $0.image != nil }
    }

    private var failedResults: [MultiPoseViewModel.PoseResult] {
        results.filter { $0.state == .failed }
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.md)
                    .padding(.bottom, EcrinSpacing.md)

                if doneResults.isEmpty {
                    emptyState
                } else {
                    Group {
                        switch displayMode {
                        case .grid:    gridLayout
                        case .carousel: carouselLayout
                        }
                    }
                    .transition(.opacity)
                }

                bottomActions
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)
                    .background {
                        Rectangle()
                            .fill(EcrinColor.surface)
                            .ignoresSafeArea(edges: .bottom)
                    }
            }

            if let result = fullScreenResult {
                fullScreenOverlay(result: result)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            if !shareImages.isEmpty {
                ShareSheet(items: shareImages)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                onClose?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(10)
                    .background(EcrinColor.glassFill, in: Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("VOS ESSAYAGES")
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                if failedResults.isEmpty {
                    Text("\(doneResults.count) vue\(doneResults.count > 1 ? "s" : "") générée\(doneResults.count > 1 ? "s" : "")")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                } else {
                    Text("\(doneResults.count) sur \(doneResults.count + failedResults.count) — \(failedResults.count) échec\(failedResults.count > 1 ? "s" : "")")
                        .font(EcrinFont.caption)
                        .foregroundStyle(.red.opacity(0.85))
                }
            }

            Spacer()

            // Toggle affichage grille / carousel
            Button {
                withAnimation(EcrinAnimation.springSnap) {
                    displayMode = displayMode == .grid ? .carousel : .grid
                }
            } label: {
                Image(systemName: displayMode == .grid ? "square.grid.2x2" : "rectangle.stack")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(10)
                    .background(EcrinColor.glassFill, in: Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Grid layout
    //
    // 1 résultat : pleine largeur, ratio 9:16 (story format)
    // 2-4 résultats : grid 2 colonnes scrollable, chaque cellule à ratio 9:16
    //                 (vertical story — format mobile natif, immersif pour
    //                 les essayages full-body).

    private static let cellAspectRatio: CGFloat = 9.0 / 16.0

    @ViewBuilder
    private var gridLayout: some View {
        let count = doneResults.count
        if count == 1 {
            ScrollView {
                resultCell(result: doneResults[0])
                    .aspectRatio(Self.cellAspectRatio, contentMode: .fit)
                    .padding(.horizontal, EcrinSpacing.xs)
            }
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ],
                    spacing: 4
                ) {
                    ForEach(doneResults) { result in
                        resultCell(result: result)
                            .aspectRatio(Self.cellAspectRatio, contentMode: .fit)
                    }
                }
                .padding(.horizontal, EcrinSpacing.xs)
                .padding(.bottom, EcrinSpacing.md)
            }
        }
    }

    /// Cellule plein cadre — scaledToFit : montre toute l'image générée
    /// (tête + pieds + mains visibles, jamais rognés). Fond noir pour le letterbox.
    private func resultCell(result: MultiPoseViewModel.PoseResult) -> some View {
        ZStack(alignment: .bottom) {
            Color.black
            if let img = result.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(EcrinColor.textMuted)
            }

            // Overlay pose name
            Text(result.pose.name.uppercased())
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(.white)
                .padding(.horizontal, EcrinSpacing.sm)
                .padding(.vertical, 4)
                .background(.black.opacity(0.45))
                .padding(.bottom, EcrinSpacing.sm)
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            withAnimation(EcrinAnimation.glassReveal) {
                fullScreenResult = result
            }
        }
        .contextMenu {
            if let img = result.image {
                Button {
                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                } label: {
                    Label("Sauvegarder", systemImage: "square.and.arrow.down")
                }
                Button {
                    shareImages = [img]
                    showShareSheet = true
                } label: {
                    Label(L10n.Common.share, systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Carousel layout

    private var carouselLayout: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(doneResults.enumerated()), id: \.element.id) { index, result in
                    carouselPage(result: result)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Page indicator
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(0..<doneResults.count, id: \.self) { index in
                    Circle()
                        .fill(index == selectedIndex ? EcrinColor.gold : EcrinColor.glassStroke)
                        .frame(width: index == selectedIndex ? 8 : 5, height: index == selectedIndex ? 8 : 5)
                        .animation(EcrinAnimation.springSnap, value: selectedIndex)
                }
            }
            .padding(.vertical, EcrinSpacing.md)
        }
    }

    private func carouselPage(result: MultiPoseViewModel.PoseResult) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if let img = result.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    Rectangle()
                        .fill(EcrinColor.glassFill)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                }

                // Overlay bas : nom de la pose + icône
                HStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: result.pose.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(EcrinColor.gold)
                    Text(result.pose.name.uppercased())
                        .font(EcrinFont.label)
                        .kerning(2.5)
                        .foregroundStyle(.white)
                    Spacer()
                    if result.pose.isMotion {
                        Text("Mouvement")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(EcrinColor.gold.opacity(0.8))
                            .kerning(1)
                    }
                }
                .padding(EcrinSpacing.md)
                .background(.black.opacity(0.55))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, EcrinSpacing.md)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onTapGesture {
            withAnimation(EcrinAnimation.glassReveal) {
                fullScreenResult = result
            }
        }
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack(spacing: EcrinSpacing.md) {
            GhostButton(title: "Tout partager") {
                let images = doneResults.compactMap(\.image)
                if !images.isEmpty {
                    shareImages = images
                    showShareSheet = true
                }
            }

            GoldButton(title: "Dressing") {
                onSaveToDressing?()
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)
            Text("Aucune vue disponible")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Full screen overlay

    private func fullScreenOverlay(result: MultiPoseViewModel.PoseResult) -> some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(EcrinAnimation.glassReveal) {
                        fullScreenResult = nil
                    }
                }

            if let img = result.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(EcrinSpacing.md)
            }

            // Fermer
            VStack {
                HStack {
                    Button {
                        withAnimation(EcrinAnimation.glassReveal) {
                            fullScreenResult = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(EcrinSpacing.lg)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Spacer()

                // Actions bas
                HStack(spacing: EcrinSpacing.lg) {
                    if let img = result.image {
                        Button {
                            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        } label: {
                            fullScreenActionButton(icon: "square.and.arrow.down", label: "Sauvegarder")
                        }
                        .buttonStyle(.plain)

                        Button {
                            shareImages = [img]
                            fullScreenResult = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showShareSheet = true
                            }
                        } label: {
                            fullScreenActionButton(icon: "square.and.arrow.up", label: L10n.Common.share)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, EcrinSpacing.xl)
            }
        }
    }

    private func fullScreenActionButton(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.15), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            Text(label)
                .font(EcrinFont.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

