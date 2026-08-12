import SwiftUI

// MARK: - Wedding Mode View

struct WeddingModeView: View {
    @StateObject private var viewModel = WeddingViewModel()
    @State private var showDatePicker = false
    @State private var pickerDate = Date()
    @State private var slotForPicker: WeddingSlot?
    @State private var showShareSheet = false
    @State private var dateCardExpanded = false

    var body: some View {
        ZStack {
            weddingBackground.ignoresSafeArea()

            // Floating gold particles
            WeddingParticlesCanvas()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.xl) {
                    headerSection
                    dateCardSection
                    completionRing
                    slotsSection
                    shareButton
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.bottom, EcrinSpacing.xxl)
            }

            // Toast overlay
            if let msg = viewModel.toastMessage {
                toastView(msg)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $pickerDate) {
                viewModel.setWeddingDate(pickerDate)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            WeddingShareView(viewModel: viewModel)
        }
        .sheet(item: $slotForPicker) { slot in
            JewelryPickerSheet(slot: slot, viewModel: viewModel)
        }
        .task {
            await viewModel.loadFromRemote()
        }
    }

    // MARK: - Background

    private var weddingBackground: some View {
        ZStack {
            Color(hex: "#0d0d0a")
            LinearGradient(
                colors: [
                    EcrinColor.gold.opacity(0.07),
                    Color.clear,
                    EcrinColor.gold.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: EcrinSpacing.sm) {
            Text("✦")
                .font(EcrinFont.serif(20))
                .foregroundStyle(EcrinColor.gold.opacity(0.7))
                .padding(.top, EcrinSpacing.lg)

            Text(L10n.WeddingUI.yourPerfectDay)
                .font(EcrinFont.label)
                .kerning(4)
                .foregroundStyle(EcrinColor.gold)

            Text(L10n.WeddingUI.bridalLook)
                .font(EcrinFont.heroTitle)
                .foregroundStyle(EcrinColor.ivory)
        }
    }

    // MARK: - Date Card (collapsible)

    private var dateCardSection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 0) {
                // Header row — always visible
                Button(action: {
                    withAnimation(EcrinAnimation.springSnap) {
                        dateCardExpanded.toggle()
                    }
                }) {
                    HStack(spacing: EcrinSpacing.md) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20, weight: .thin))
                            .foregroundStyle(EcrinColor.gold)

                        VStack(alignment: .leading, spacing: 2) {
                            if let date = viewModel.weddingLook.weddingDate {
                                Text(date.formatted(date: .long, time: .omitted))
                                    .font(EcrinFont.body)
                                    .foregroundStyle(EcrinColor.textPrimary)
                            } else {
                                Text(L10n.WeddingUI.setWeddingDate)
                                    .font(EcrinFont.body)
                                    .foregroundStyle(EcrinColor.textSecondary)
                            }
                        }

                        Spacer()

                        Text(viewModel.countdownLabel)
                            .font(EcrinFont.serif(20, weight: .regular))
                            .foregroundStyle(EcrinColor.gold)
                            .padding(.horizontal, EcrinSpacing.md)
                            .padding(.vertical, EcrinSpacing.xs)
                            .background(EcrinColor.gold.opacity(0.12))
                            .clipShape(Capsule())

                        Image(systemName: dateCardExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                    .padding(EcrinSpacing.md)
                }
                .buttonStyle(.plain)

                // Expanded date picker
                if dateCardExpanded {
                    Divider()
                        .background(EcrinColor.glassStroke)

                    VStack(spacing: EcrinSpacing.md) {
                        DatePicker(
                            "",
                            selection: $pickerDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .tint(EcrinColor.gold)
                        .colorScheme(.dark)
                        .labelsHidden()

                        GoldButton(title: L10n.WeddingUI.confirm) {
                            viewModel.setWeddingDate(pickerDate)
                            withAnimation(EcrinAnimation.springSnap) {
                                dateCardExpanded = false
                            }
                        }
                        .padding(.bottom, EcrinSpacing.md)
                    }
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.top, EcrinSpacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            if let date = viewModel.weddingLook.weddingDate {
                pickerDate = date
            }
        }
    }

    // MARK: - Circular completion ring

    private var completionRing: some View {
        HStack(spacing: EcrinSpacing.xl) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(EcrinColor.glassFill, lineWidth: 6)
                    .frame(width: 88, height: 88)

                // Gold progress arc
                Circle()
                    .trim(from: 0, to: viewModel.weddingLook.completionPercent)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [EcrinColor.gold, EcrinColor.goldLight, EcrinColor.gold]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 88, height: 88)
                    .animation(EcrinAnimation.easeSlide, value: viewModel.weddingLook.completionPercent)

                // Percentage label
                VStack(spacing: 0) {
                    Text("\(viewModel.completionPercent)")
                        .font(EcrinFont.serif(22, weight: .regular))
                        .foregroundStyle(EcrinColor.gold)
                    Text("%")
                        .font(EcrinFont.label)
                        .kerning(1)
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }

            VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                Text(L10n.WeddingUI.completionLabel)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)

                Text("\(viewModel.weddingLook.pieces.count) / \(WeddingSlot.allCases.count) emplacements")
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary)

                if viewModel.weddingLook.completionPercent == 1.0 {
                    HStack(spacing: EcrinSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(EcrinColor.gold)
                        Text(L10n.WeddingUI.lookComplete)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.gold)
                    }
                }
            }

            Spacer()
        }
        .padding(EcrinSpacing.md)
        .background(
            GlassCard(cornerRadius: 20) {
                Color.clear
            }
        )
    }

    // MARK: - Slots Grid (2 columns)

    private var slotsSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            Text(L10n.WeddingUI.placementsLabel)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            let columns = [
                GridItem(.flexible(), spacing: EcrinSpacing.md),
                GridItem(.flexible(), spacing: EcrinSpacing.md)
            ]

            LazyVGrid(columns: columns, spacing: EcrinSpacing.md) {
                ForEach(WeddingSlot.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { slot in
                    WeddingSlotCard(
                        slot: slot,
                        piece: viewModel.weddingLook.piece(for: slot),
                        onTap: { slotForPicker = slot },
                        onRemove: {
                            withAnimation(EcrinAnimation.springSnap) {
                                viewModel.removePiece(for: slot)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        GhostButton(title: L10n.WeddingUI.shareWithBridesmaids) {
            showShareSheet = true
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toast

    private func toastView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.background)
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.vertical, EcrinSpacing.md)
                .background(EcrinColor.gold)
                .clipShape(Capsule())
                .padding(.bottom, EcrinSpacing.xxl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(EcrinAnimation.springSnap, value: viewModel.toastMessage)
    }
}

// MARK: - Wedding Particles Canvas (ambient drift — différent du burst Gaming)

struct WeddingParticlesCanvas: View {
    @State private var particles: [WeddingParticle] = (0..<14).map { _ in WeddingParticle() }
    @State private var tick: CGFloat = 0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            for p in particles {
                let progress = tick.truncatingRemainder(dividingBy: p.duration) / p.duration
                let x = p.startX * size.width
                let yBase = size.height * (1.0 - progress)
                let y = yBase + sin(progress * .pi * 2.0 + p.phase) * 20.0
                let alpha = sin(progress * .pi) * 0.5 * p.alpha

                let r = p.radius * (0.85 + sin(progress * .pi) * 0.15)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2.0, height: r * 2.0)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(EcrinColor.gold.opacity(alpha))
                )
            }
        }
        .onReceive(timer) { _ in
            tick += 0.05
        }
    }
}

private struct WeddingParticle {
    let startX: CGFloat   = .random(in: 0...1)
    let duration: CGFloat = .random(in: 7...15)
    let phase: CGFloat    = .random(in: 0...(.pi * 2))
    let alpha: CGFloat    = .random(in: 0.35...1.0)
    let radius: CGFloat   = .random(in: 1.5...3.5)
}

// MARK: - Date Picker Sheet

private struct DatePickerSheet: View {
    @Binding var date: Date
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack(spacing: EcrinSpacing.lg) {
                Text(L10n.WeddingUI.weddingDate)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .padding(.top, EcrinSpacing.xl)

                DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(EcrinColor.gold)
                    .colorScheme(.dark)
                    .padding(.horizontal)

                GoldButton(title: L10n.WeddingUI.confirm) {
                    onSave()
                    dismiss()
                }
                .padding(.bottom, EcrinSpacing.xl)
            }
        }
    }
}

// MARK: - Jewelry Picker Sheet

private struct JewelryPickerSheet: View {
    let slot: WeddingSlot
    @ObservedObject var viewModel: WeddingViewModel
    @Environment(\.dismiss) private var dismiss

    private let items = JewelryItem.samples

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack(spacing: EcrinSpacing.lg) {
                Capsule()
                    .fill(EcrinColor.glassStroke)
                    .frame(width: 40, height: 4)
                    .padding(.top, EcrinSpacing.md)

                VStack(spacing: 4) {
                    Text(L10n.WeddingUI.chooseJewel)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(slot.rawValue)
                        .font(EcrinFont.label)
                        .kerning(2)
                        .foregroundStyle(EcrinColor.gold)

                    Text(slot.hint)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, EcrinSpacing.xl)
                        .padding(.top, EcrinSpacing.xs)
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: EcrinSpacing.sm) {
                        ForEach(items) { item in
                            Button {
                                viewModel.addPiece(jewelry: item, to: slot)
                                dismiss()
                            } label: {
                                GlassCard(cornerRadius: 16) {
                                    HStack(spacing: EcrinSpacing.md) {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 28, weight: .thin))
                                            .foregroundStyle(EcrinColor.gold)
                                            .frame(width: 56, height: 56)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(EcrinFont.cardTitle)
                                                .foregroundStyle(EcrinColor.textPrimary)
                                            Text(item.material)
                                                .font(EcrinFont.caption)
                                                .foregroundStyle(EcrinColor.textSecondary)
                                            Text(item.category.rawValue)
                                                .font(EcrinFont.label)
                                                .kerning(1)
                                                .foregroundStyle(EcrinColor.textMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .thin))
                                            .foregroundStyle(EcrinColor.gold)
                                            .padding(.trailing, EcrinSpacing.md)
                                    }
                                    .padding(EcrinSpacing.md)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.xxl)
                }
            }
        }
    }
}
