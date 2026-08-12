import SwiftUI
import PhotosUI

// MARK: - OutfitBuilderView

struct OutfitBuilderView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var vm = OutfitViewModel()
    @State private var showWardrobe    = false
    @State private var showResult      = false
    @State private var showGallery     = false
    @State private var showOccasionPicker = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // --- Header ---
                header

                // --- Canvas silhouette (60%) ---
                GeometryReader { geo in
                    SilhouetteCanvas(vm: vm)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                Divider()
                    .background(EcrinColor.glassStroke)

                // --- Sélecteur (40%) ---
                VStack(spacing: 0) {
                    groupTabs
                    itemScrollView
                }
                .frame(height: 180)

                // --- Bottom bar ---
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showResult) {
            if let img = vm.result {
                OutfitResultView(image: img, outfit: vm.currentOutfit, vm: vm)
            }
        }
        .sheet(isPresented: $showGallery) {
            OutfitGalleryView(vm: vm)
        }
        .alert("Conflits détectés", isPresented: $vm.showConflictWarning) {
            Button(L10n.OutfitBuilderUI.continueAnyway) { vm.showConflictWarning = false }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(vm.conflicts.joined(separator: "\n"))
                .font(EcrinFont.body)
        }
        .task {
            vm.availableItems = appState.wardrobe.items.isEmpty
                ? FashionItem.samples
                : appState.wardrobe.items
        }
        .onChange(of: appState.wardrobe.items) { _, items in
            if !items.isEmpty { vm.availableItems = items }
        }
        .onChange(of: vm.selectedPhotoItem) { _, newItem in
            Task { await vm.loadPhoto(from: newItem) }
        }
        .onChange(of: vm.result) { _, newResult in
            if newResult != nil { showResult = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Retour / Galerie
            Button { showGallery = true } label: {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(EcrinColor.gold)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(L10n.OutfitBuilderUI.outfitBuilder)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.ivory)
                // Occasion badge
                Button { showOccasionPicker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vm.currentOutfit.occasion.icon)
                            .font(.system(size: 10))
                        Text(vm.currentOutfit.occasion.rawValue)
                            .font(EcrinFont.caption)
                    }
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, EcrinSpacing.sm)
                    .padding(.vertical, 3)
                    .background(EcrinColor.gold.opacity(0.12), in: Capsule())
                }
            }

            Spacer()

            // Reset
            Button { vm.clearOutfit() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18))
                    .foregroundStyle(EcrinColor.textSecondary)
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .sheet(isPresented: $showOccasionPicker) {
            OccasionPickerSheet(selected: $vm.currentOutfit.occasion)
                .presentationDetents([.height(300)])
        }
    }

    // MARK: - Group tabs

    private var groupTabs: some View {
        HStack(spacing: 0) {
            ForEach(FashionGroup.allCases, id: \.self) { group in
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        vm.selectedGroup = group
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: group.icon)
                            .font(.system(size: 14))
                        Text(group.rawValue)
                            .font(EcrinFont.label)
                            .kerning(1)
                    }
                    .foregroundStyle(vm.selectedGroup == group ? EcrinColor.gold : EcrinColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EcrinSpacing.sm)
                    .overlay(alignment: .bottom) {
                        if vm.selectedGroup == group {
                            Rectangle()
                                .fill(EcrinColor.gold)
                                .frame(height: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(EcrinColor.surface)
    }

    // MARK: - Items scroll

    private var itemScrollView: some View {
        let items = vm.availableItems.filter { $0.category.group == vm.selectedGroup }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(items) { item in
                    ItemChip(item: item) {
                        withAnimation(EcrinAnimation.springSnap) {
                            vm.autoAssignItem(item)
                        }
                    }
                }

                if items.isEmpty {
                    Text(L10n.OutfitBuilderUI.noItemsInCategory)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .padding(.horizontal, EcrinSpacing.lg)
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
        }
        .background(EcrinColor.surface)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: EcrinSpacing.md) {
            // Photo picker
            PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: vm.userPhoto != nil ? "person.fill.checkmark" : "person.crop.circle.badge.plus")
                        .font(.system(size: 16))
                    Text(vm.userPhoto != nil ? "Photo" : "Ma photo")
                        .font(EcrinFont.cta)
                        .kerning(1.5)
                }
                .foregroundStyle(vm.userPhoto != nil ? EcrinColor.gold : EcrinColor.textSecondary)
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.vertical, EcrinSpacing.sm)
                .background(EcrinColor.glassFill, in: Capsule())
                .overlay(Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }

            // Generate button
            Button {
                Task { await vm.generate() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isGenerating {
                        ProgressView()
                            .tint(EcrinColor.background)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14))
                    }
                    Text(vm.isGenerating ? "Génération…" : "Générer le look")
                        .font(EcrinFont.cta)
                        .kerning(2)
                        .textCase(.uppercase)
                }
                .foregroundStyle(EcrinColor.background)
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.vertical, EcrinSpacing.md)
                .background(
                    vm.currentOutfit.isReadyToGenerate
                        ? EcrinColor.gold
                        : EcrinColor.gold.opacity(0.35),
                    in: Capsule()
                )
            }
            .disabled(!vm.currentOutfit.isReadyToGenerate || vm.isGenerating)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background {
            Rectangle()
                .fill(EcrinColor.surface)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - SilhouetteCanvas

struct SilhouetteCanvas: View {
    @ObservedObject var vm: OutfitViewModel

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let scale  = min(geo.size.width, geo.size.height) * 0.42

            ZStack {
                // Silhouette humaine dessinée en SwiftUI Path
                HumanSilhouette()
                    .fill(EcrinColor.ivory.opacity(0.04))
                    .overlay(
                        HumanSilhouette()
                            .stroke(EcrinColor.ivory.opacity(0.12), lineWidth: 0.8)
                    )
                    .frame(width: scale * 1.1, height: scale * 2.4)
                    .position(center)

                // Score de complétude
                CompletionBadge(score: vm.currentOutfit.completionScore)
                    .position(x: geo.size.width - 52, y: 24)

                // Hotspots sur la silhouette
                ForEach(OutfitSlot.allCases, id: \.self) { slot in
                    let pos = slotPosition(slot: slot, center: center, scale: scale)
                    SlotHotspot(
                        slot: slot,
                        filledRef: vm.currentOutfit.slots[slot]
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            vm.removeItem(from: slot)
                        }
                    }
                    .position(pos)
                }

                // Message d'aide si vide
                if vm.currentOutfit.slots.isEmpty {
                    VStack(spacing: EcrinSpacing.sm) {
                        Image(systemName: "hand.point.down.fill")
                            .font(.system(size: 20))
                        Text(L10n.OutfitBuilderUI.selectPiecesBelow)
                            .font(EcrinFont.caption)
                    }
                    .foregroundStyle(EcrinColor.textMuted)
                    .position(x: center.x, y: geo.size.height - 50)
                }
            }
        }
    }

    // Convertit la position normalisée (-1..1) en coordonnées screen
    private func slotPosition(slot: OutfitSlot, center: CGPoint, scale: CGFloat) -> CGPoint {
        let norm = slot.silhouettePosition
        return CGPoint(
            x: center.x + norm.x * scale,
            y: center.y + norm.y * scale * 2.2
        )
    }
}

// MARK: - HumanSilhouette (SwiftUI Path)

struct HumanSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX

        // Helper
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: cx + x * w * 0.5, y: rect.minY + y * h)
        }

        // Tete
        let headCenter = CGPoint(x: cx, y: rect.minY + 0.07 * h)
        let headRadius = w * 0.145
        path.addEllipse(in: CGRect(x: headCenter.x - headRadius,
                                    y: headCenter.y - headRadius,
                                    width:  headRadius * 2,
                                    height: headRadius * 2.15))

        // Cou
        path.move(to: pt(-0.07, 0.155))
        path.addLine(to: pt(-0.07, 0.195))
        path.addCurve(to: pt(0.07, 0.195),
                      control1: pt(-0.07, 0.215), control2: pt(0.07, 0.215))
        path.addLine(to: pt(0.07, 0.155))
        path.addCurve(to: pt(-0.07, 0.155),
                      control1: pt(0.07, 0.14), control2: pt(-0.07, 0.14))

        // Epaules + tronc + hanches
        path.move(to: pt(-0.5, 0.22))
        path.addCurve(to: pt(-0.25, 0.19),
                      control1: pt(-0.5, 0.19), control2: pt(-0.35, 0.185))
        path.addCurve(to: pt(-0.22, 0.22),
                      control1: pt(-0.18, 0.193), control2: pt(-0.22, 0.21))
        // Côté gauche torse
        path.addCurve(to: pt(-0.24, 0.48),
                      control1: pt(-0.25, 0.32), control2: pt(-0.26, 0.42))
        // Hanche gauche
        path.addCurve(to: pt(-0.28, 0.56),
                      control1: pt(-0.23, 0.52), control2: pt(-0.28, 0.53))
        // Jambe gauche extérieure
        path.addLine(to: pt(-0.21, 0.78))
        path.addCurve(to: pt(-0.19, 0.98),
                      control1: pt(-0.22, 0.88), control2: pt(-0.20, 0.95))
        // Pied gauche
        path.addLine(to: pt(-0.22, 0.995))
        path.addLine(to: pt(-0.10, 0.995))
        path.addLine(to: pt(-0.10, 0.98))
        // Jambe gauche intérieure
        path.addLine(to: pt(-0.06, 0.62))
        // Entrejambe
        path.addCurve(to: pt(0.06, 0.62),
                      control1: pt(-0.03, 0.66), control2: pt(0.03, 0.66))
        // Jambe droite intérieure
        path.addLine(to: pt(0.10, 0.98))
        path.addLine(to: pt(0.10, 0.995))
        // Pied droit
        path.addLine(to: pt(0.22, 0.995))
        path.addLine(to: pt(0.19, 0.98))
        // Jambe droite extérieure
        path.addCurve(to: pt(0.21, 0.78),
                      control1: pt(0.20, 0.95), control2: pt(0.22, 0.88))
        path.addLine(to: pt(0.28, 0.56))
        // Hanche droite
        path.addCurve(to: pt(0.24, 0.48),
                      control1: pt(0.28, 0.53), control2: pt(0.23, 0.52))
        // Côté droit torse
        path.addCurve(to: pt(0.22, 0.22),
                      control1: pt(0.26, 0.42), control2: pt(0.25, 0.32))
        path.addCurve(to: pt(0.25, 0.19),
                      control1: pt(0.22, 0.21), control2: pt(0.18, 0.193))
        // Épaule droite
        path.addCurve(to: pt(0.5, 0.22),
                      control1: pt(0.35, 0.185), control2: pt(0.5, 0.19))

        // Bras droit extérieur
        path.addCurve(to: pt(0.55, 0.52),
                      control1: pt(0.6, 0.30), control2: pt(0.60, 0.46))
        path.addCurve(to: pt(0.45, 0.54),
                      control1: pt(0.51, 0.56), control2: pt(0.47, 0.57))
        path.addLine(to: pt(0.40, 0.22))
        path.closeSubpath()

        // Bras gauche (miroir)
        path.move(to: pt(-0.40, 0.22))
        path.addLine(to: pt(-0.45, 0.54))
        path.addCurve(to: pt(-0.55, 0.52),
                      control1: pt(-0.47, 0.57), control2: pt(-0.51, 0.56))
        path.addCurve(to: pt(-0.50, 0.22),
                      control1: pt(-0.60, 0.46), control2: pt(-0.60, 0.30))
        path.closeSubpath()

        return path
    }
}

// MARK: - SlotHotspot

struct SlotHotspot: View {
    let slot: OutfitSlot
    let filledRef: FashionItemRef?
    let onRemove: () -> Void

    @State private var pulseOpacity: Double = 0.4

    var body: some View {
        ZStack {
            if let ref = filledRef {
                // Slot rempli
                filledView(ref: ref)
            } else {
                // Slot vide : cercle pulsant
                emptyView
            }
        }
    }

    private var emptyView: some View {
        ZStack {
            Circle()
                .fill(EcrinColor.gold.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(EcrinColor.gold.opacity(pulseOpacity), lineWidth: 1))
                .animation(
                    Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: pulseOpacity
                )
                .onAppear { pulseOpacity = 1.0 }

            Image(systemName: slot.icon)
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(EcrinColor.gold.opacity(0.7))
        }
    }

    private func filledView(ref: FashionItemRef) -> some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(EcrinColor.gold.opacity(0.25))
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(EcrinColor.gold, lineWidth: 1.5))

            Image(systemName: ref.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(EcrinColor.gold)

            // Bouton supprimer
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(EcrinColor.ivory)
                    .background(Circle().fill(EcrinColor.background))
            }
            .offset(x: 6, y: -6)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - ItemChip

struct ItemChip: View {
    let item: FashionItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(item.category.group.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(item.category.group.color)
                }
                Text(item.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 60)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CompletionBadge

struct CompletionBadge: View {
    let score: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(score)%")
                .font(EcrinFont.sans(13, weight: .bold))
                .foregroundStyle(score >= 70 ? EcrinColor.gold : EcrinColor.textSecondary)
            Text(L10n.OutfitBuilderUI.outfit)
                .font(EcrinFont.label)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(EcrinColor.glassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke)
        )
    }
}

// MARK: - OccasionPickerSheet

struct OccasionPickerSheet: View {
    @Binding var selected: OutfitOccasion
    @Environment(\.dismiss) private var dismiss

    let columns = [GridItem(.adaptive(minimum: 80))]

    var body: some View {
        VStack(spacing: EcrinSpacing.md) {
            Text("Occasion")
                .font(EcrinFont.sectionHead)
                .foregroundStyle(EcrinColor.ivory)
                .padding(.top, EcrinSpacing.md)

            LazyVGrid(columns: columns, spacing: EcrinSpacing.md) {
                ForEach(OutfitOccasion.allCases, id: \.self) { occasion in
                    Button {
                        selected = occasion
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: occasion.icon)
                                .font(.system(size: 20))
                            Text(occasion.rawValue)
                                .font(EcrinFont.caption)
                        }
                        .foregroundStyle(selected == occasion ? EcrinColor.gold : EcrinColor.textSecondary)
                        .padding(EcrinSpacing.sm)
                        .background(
                            selected == occasion ? EcrinColor.gold.opacity(0.15) : EcrinColor.glassFill,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    selected == occasion ? EcrinColor.gold.opacity(0.5) : EcrinColor.glassStroke
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
        }
        .padding(.bottom, EcrinSpacing.lg)
        .background(EcrinColor.surface.ignoresSafeArea())
    }
}
