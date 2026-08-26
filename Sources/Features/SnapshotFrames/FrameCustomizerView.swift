import SwiftUI

// MARK: - Frame Customizer Sheet

struct FrameCustomizerView: View {
    @State private var workingFrame: SnapshotFrame
    let onSave: (SnapshotFrame) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedColor: Color
    @State private var borderWidth: CGFloat
    @State private var polaroidText: String
    @State private var showDate: Bool
    @State private var showJewelryName: Bool
    @State private var cornerRadius: CGFloat

    init(frame: SnapshotFrame, onSave: @escaping (SnapshotFrame) -> Void) {
        self._workingFrame = State(initialValue: frame)
        self.onSave = onSave
        self._selectedColor = State(initialValue: Color(hex: frame.style.borderColor))
        self._borderWidth = State(initialValue: frame.style.borderWidth)
        self._polaroidText = State(initialValue: frame.style.bottomText ?? "")
        self._showDate = State(initialValue: frame.style.showDate)
        self._showJewelryName = State(initialValue: frame.style.showJewelryName)
        self._cornerRadius = State(initialValue: frame.style.cornerRadius)
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EcrinSpacing.xl) {
                        // Mini live preview
                        livePreview

                        // Controls
                        VStack(spacing: EcrinSpacing.lg) {
                            colorSection
                            borderWidthSection
                            cornerRadiusSection
                            if workingFrame.category == .polaroid {
                                polaroidTextSection
                            }
                            togglesSection
                        }
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.bottom, EcrinSpacing.xxl)
                    }
                    .padding(.top, EcrinSpacing.md)
                }

                // Bottom actions
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedColor) { _, _ in syncToFrame() }
        .onChange(of: borderWidth)  { _, _ in syncToFrame() }
        .onChange(of: cornerRadius) { _, _ in syncToFrame() }
        .onChange(of: polaroidText) { _, _ in syncToFrame() }
        .onChange(of: showDate)     { _, _ in syncToFrame() }
        .onChange(of: showJewelryName) { _, _ in syncToFrame() }
    }

    // MARK: Sync

    private func syncToFrame() {
        let hexStr = selectedColor.toHex() ?? workingFrame.style.borderColor
        workingFrame = SnapshotFrame(
            id: workingFrame.id,
            name: workingFrame.name,
            category: workingFrame.category,
            isPremium: workingFrame.isPremium,
            isUnlockableByXP: workingFrame.isUnlockableByXP,
            xpRequired: workingFrame.xpRequired,
            style: FrameStyle(
                borderColor: hexStr,
                borderWidth: borderWidth,
                cornerRadius: cornerRadius,
                innerPadding: workingFrame.style.innerPadding,
                backgroundColor: workingFrame.style.backgroundColor,
                topText: workingFrame.style.topText,
                bottomText: polaroidText.isEmpty ? nil : polaroidText,
                overlay: workingFrame.style.overlay,
                showDate: showDate,
                showJewelryName: showJewelryName
            )
        )
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(EcrinColor.glassFill)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(L10n.SnapshotFramesUI.customizeCaps)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(workingFrame.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, EcrinSpacing.lg)
        .padding(.bottom, EcrinSpacing.md)
    }

    // MARK: Live Preview

    private var livePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(EcrinColor.glassFill)

            // Simulated image fill
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2A2A2E"), Color(hex: "#111114")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(workingFrame.style.borderWidth)

            Image(systemName: "person.fill")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)

            FrameSwiftUIView(frame: workingFrame, size: CGSize(width: 160, height: 200))
        }
        .frame(width: 160, height: 200)
        .shadow(color: selectedColor.opacity(0.3), radius: 12, x: 0, y: 6)
        .animation(EcrinAnimation.springSnap, value: borderWidth)
        .animation(EcrinAnimation.springSnap, value: cornerRadius)
    }

    // MARK: Sections

    private var colorSection: some View {
        customSection(title: "COULEUR DU CADRE", icon: "paintpalette") {
            VStack(spacing: EcrinSpacing.md) {
                // Quick palette
                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(quickPalette, id: \.self) { hex in
                        Button {
                            withAnimation(EcrinAnimation.springSnap) {
                                selectedColor = Color(hex: hex)
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(
                                        selectedColor.toHex()?.lowercased() == hex.lowercased()
                                        ? Color.white : Color.clear,
                                        lineWidth: 2
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                }
            }
        }
    }

    private let quickPalette: [String] = [
        "#CA8A04", "#D4AF37", "#C0C0C0", "#FAFAF9",
        "#1A1A1A", "#CC3355", "#8A3AAA", "#40A0C8"
    ]

    private var borderWidthSection: some View {
        customSection(title: "ÉPAISSEUR — \(Int(borderWidth))pt", icon: "line.diagonal") {
            Slider(value: $borderWidth, in: 2...20, step: 1)
                .tint(EcrinColor.gold)
        }
    }

    private var cornerRadiusSection: some View {
        customSection(title: "ARRONDI — \(Int(cornerRadius))pt", icon: "square.on.square") {
            Slider(value: $cornerRadius, in: 0...30, step: 1)
                .tint(EcrinColor.gold)
        }
    }

    private var polaroidTextSection: some View {
        customSection(title: "TEXTE POLAROID", icon: "character.cursor.ibeam") {
            ZStack(alignment: .leading) {
                if polaroidText.isEmpty {
                    Text(L10n.SnapshotFramesUI.titlePlaceholder)
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textMuted)
                        .padding(.horizontal, EcrinSpacing.md)
                }
                TextField("", text: $polaroidText)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, EcrinSpacing.sm)
            }
            .background(EcrinColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
            )
            .onChange(of: polaroidText) { _, new in
                if new.count > 30 { polaroidText = String(new.prefix(30)) }
            }
        }
    }

    private var togglesSection: some View {
        VStack(spacing: EcrinSpacing.sm) {
            customToggle(
                title: "Afficher la date automatiquement",
                subtitle: "La date du jour sera inscrite sur le cadre",
                icon: "calendar",
                isOn: $showDate
            )
            customToggle(
                title: "Afficher le nom du bijou",
                subtitle: "\"L'ÉCRIN VIRTUEL\" apparaîtra sur le cadre",
                icon: "diamond",
                isOn: $showJewelryName
            )
        }
    }

    // MARK: Section Builder

    private func customSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(EcrinColor.gold)
                Text(title)
                    .font(EcrinFont.label)
                    .kerning(1.5)
                    .foregroundStyle(EcrinColor.textMuted)
            }
            content()
        }
    }

    private func customToggle(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: EcrinSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .thin))
                .foregroundStyle(isOn.wrappedValue ? EcrinColor.gold : EcrinColor.textMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text(subtitle)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(EcrinColor.gold)
        }
        .padding(EcrinSpacing.md)
        .background(EcrinColor.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        )
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: EcrinSpacing.md) {
            GhostButton(title: L10n.Common.cancel) {
                dismiss()
            }
            GoldButton(title: L10n.Common.save) {
                syncToFrame()
                onSave(workingFrame)
                dismiss()
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

// MARK: - Color → Hex helper

extension Color {
    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(r * 255), gi = Int(g * 255), bi = Int(b * 255)
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}
