import SwiftUI

// MARK: - Gift Creator View
struct GiftCreatorView: View {
    @StateObject private var viewModel = GiftViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// Expéditeur réel — le destinataire voyait « De la part de Vous »
    /// (moi@example.com) avec l'utilisateur simulé précédent.
    private var currentUser: User {
        appState.currentUser ?? User(email: "", displayName: nil, createdAt: .now)
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                GiftCreatorHeader(
                    step: viewModel.currentStep,
                    onDismiss: { dismiss() }
                )

                // Stepper indicator
                GiftStepperBar(currentStep: viewModel.currentStep) { step in
                    if step.rawValue < viewModel.currentStep.rawValue {
                        viewModel.goTo(step)
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.top, EcrinSpacing.md)

                // Step content
                TabView(selection: $viewModel.currentStep) {
                    GiftStep1ChooseJewelry(viewModel: viewModel)
                        .tag(GiftCreatorStep.chooseJewelry)

                    GiftStep2Customize(viewModel: viewModel)
                        .tag(GiftCreatorStep.customize)

                    GiftStep3Send(viewModel: viewModel, currentUser: currentUser)
                        .tag(GiftCreatorStep.send)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(EcrinAnimation.easeSlide, value: viewModel.currentStep)
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.shareURL {
                GiftShareSheet(url: url, gift: viewModel.createdGift)
            }
        }
        .task { await viewModel.loadJewelryCatalog() }
    }
}

// MARK: - Header
private struct GiftCreatorHeader: View {
    let step: GiftCreatorStep
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.GiftUI.giftCaps)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(L10n.GiftUI.magical)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(10)
                    .background(EcrinColor.glassFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, EcrinSpacing.lg)
    }
}

// MARK: - Stepper Bar
private struct GiftStepperBar: View {
    let currentStep: GiftCreatorStep
    let onTap: (GiftCreatorStep) -> Void

    var body: some View {
        HStack(spacing: EcrinSpacing.sm) {
            ForEach(GiftCreatorStep.allCases, id: \.rawValue) { step in
                let isActive = step == currentStep
                let isPast   = step.rawValue < currentStep.rawValue

                Button { onTap(step) } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActive || isPast ? EcrinColor.gold : EcrinColor.glassFill)
                            .overlay {
                                if isActive || isPast {
                                    Text("\(step.rawValue + 1)")
                                        .font(EcrinFont.caption)
                                        .foregroundStyle(EcrinColor.background)
                                } else {
                                    Text("\(step.rawValue + 1)")
                                        .font(EcrinFont.caption)
                                        .foregroundStyle(EcrinColor.textMuted)
                                }
                            }
                            .frame(width: 24, height: 24)

                        if isActive {
                            Text(step.title)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.gold)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .animation(EcrinAnimation.springSnap, value: currentStep)
                }
                .buttonStyle(.plain)

                if step.rawValue < GiftCreatorStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue
                              ? EcrinColor.gold.opacity(0.5)
                              : EcrinColor.glassStroke)
                        .frame(height: 1)
                        .animation(EcrinAnimation.easeSlide, value: currentStep)
                }
            }
        }
    }
}

// MARK: - Step 1: Choose Jewelry
private struct GiftStep1ChooseJewelry: View {
    @ObservedObject var viewModel: GiftViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                Text(L10n.GiftUI.whichJewelToGift)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Grid of tried-on jewelry
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: EcrinSpacing.md),
                              GridItem(.flexible(), spacing: EcrinSpacing.md)],
                    spacing: EcrinSpacing.md
                ) {
                    ForEach(viewModel.availableTryOns) { entry in
                        GiftJewelryCard(
                            entry: entry,
                            isSelected: viewModel.selectedJewelry?.id == entry.jewelry.id
                        )
                        .onTapGesture {
                            withAnimation(EcrinAnimation.springSnap) {
                                viewModel.selectedJewelry = entry.jewelry
                                viewModel.selectedTryOnImage = entry.image
                            }
                        }
                    }
                }

                Spacer(minLength: EcrinSpacing.xl)

                GoldButton(title: L10n.Common.next) { viewModel.next() }
                    .disabled(!viewModel.canProceedToCustomize)
                    .opacity(viewModel.canProceedToCustomize ? 1 : 0.35)
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.top, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.xxl)
        }
    }
}

private struct GiftJewelryCard: View {
    let entry: TryOnEntry
    let isSelected: Bool

    var body: some View {
        GlassCard(cornerRadius: 18) {
            VStack(spacing: EcrinSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(EcrinColor.gold.opacity(0.06))
                        .frame(height: 120)

                    if let img = entry.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: entry.jewelry.icon)
                            .font(.system(size: 38, weight: .thin))
                            .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                    }
                }

                VStack(spacing: 2) {
                    Text(entry.jewelry.name)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(entry.jewelry.material)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                }
                .padding(.bottom, EcrinSpacing.sm)
            }
            .padding(.top, EcrinSpacing.sm)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected ? EcrinColor.gold : Color.clear,
                    lineWidth: 1.5
                )
        }
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Step 2: Customize
private struct GiftStep2Customize: View {
    @ObservedObject var viewModel: GiftViewModel
    @FocusState private var messageIsFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                Text(L10n.GiftUI.personalize)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Occasion chips
                VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                    Text(L10n.OccasionVaultUI.occasionLabel)
                        .font(EcrinFont.label)
                        .kerning(2)
                        .foregroundStyle(EcrinColor.textMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: EcrinSpacing.sm) {
                            ForEach(GiftOccasion.allCases, id: \.self) { occ in
                                OccasionChip(
                                    occasion: occ,
                                    isSelected: viewModel.occasion == occ
                                )
                                .onTapGesture {
                                    withAnimation(EcrinAnimation.springSnap) {
                                        viewModel.occasion = occ
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                }

                // Message field
                VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                    Text(L10n.GiftUI.yourMessageCaps)
                        .font(EcrinFont.label)
                        .kerning(2)
                        .foregroundStyle(EcrinColor.textMuted)

                    GlassCard(cornerRadius: 16) {
                        TextField(
                            L10n.GiftUI.writeWordsWithLove,
                            text: $viewModel.message,
                            axis: .vertical
                        )
                        .font(EcrinFont.serif(16, weight: .light))
                        .foregroundStyle(EcrinColor.textPrimary)
                        .tint(EcrinColor.gold)
                        .lineLimit(4...8)
                        .focused($messageIsFocused)
                        .padding(EcrinSpacing.md)
                    }
                }

                // Preview card
                if let jewelry = viewModel.selectedJewelry {
                    GiftCardPreview(
                        jewelry: jewelry,
                        tryOnImage: viewModel.selectedTryOnImage,
                        message: viewModel.message.isEmpty ? "Votre message apparaîtra ici…" : viewModel.message,
                        occasion: viewModel.occasion
                    )
                }

                HStack(spacing: EcrinSpacing.md) {
                    GhostButton(title: L10n.Common.previous) { viewModel.previous() }
                    GoldButton(title: L10n.WeatherUI.continueAction) { viewModel.next() }
                        .disabled(!viewModel.canProceedToSend)
                        .opacity(viewModel.canProceedToSend ? 1 : 0.35)
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.top, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.xxl)
        }
        .onTapGesture { messageIsFocused = false }
    }
}

private struct OccasionChip: View {
    let occasion: GiftOccasion
    let isSelected: Bool

    var body: some View {
        Text(occasion.displayLabel)
            .font(EcrinFont.caption)
            .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                        lineWidth: 0.5
                    )
            }
            .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Gift Card Preview (also used in step 3)
struct GiftCardPreview: View {
    let jewelry: JewelryItem
    let tryOnImage: UIImage?
    let message: String
    let occasion: GiftOccasion

    var body: some View {
        ZStack {
            // Dark gold gradient background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1A1200"),
                            Color(hex: "#0A0A0A"),
                            Color(hex: "#1A0E00")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle gold shimmer overlay
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [EcrinColor.gold.opacity(0.08), Color.clear, EcrinColor.gold.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 1)

            VStack(spacing: EcrinSpacing.lg) {
                // Occasion badge
                Text(occasion.displayLabel)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, 5)
                    .background(EcrinColor.gold.opacity(0.12))
                    .clipShape(Capsule())

                // Jewelry image or icon
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold.opacity(0.08))
                        .frame(width: 110, height: 110)
                    Circle()
                        .strokeBorder(EcrinColor.gold.opacity(0.2), lineWidth: 1)
                        .frame(width: 110, height: 110)

                    if let img = tryOnImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: jewelry.icon)
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(EcrinColor.gold)
                    }
                }

                // Jewelry name
                VStack(spacing: 4) {
                    Text(jewelry.name)
                        .font(EcrinFont.serif(24, weight: .regular))
                        .foregroundStyle(EcrinColor.ivory)

                    Text(jewelry.material)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.gold.opacity(0.8))
                        .kerning(1.5)
                        .textCase(.uppercase)
                }

                // Divider
                HStack {
                    Rectangle().fill(EcrinColor.gold.opacity(0.3)).frame(height: 0.5)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(EcrinColor.gold.opacity(0.5))
                    Rectangle().fill(EcrinColor.gold.opacity(0.3)).frame(height: 0.5)
                }
                .padding(.horizontal, EcrinSpacing.xl)

                // Message
                Text(message)
                    .font(EcrinFont.serif(16, weight: .light))
                    .italic()
                    .foregroundStyle(EcrinColor.ivory.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, EcrinSpacing.md)

                // Footer
                Text(L10n.GiftUI.givenWithLove)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .kerning(1)
            }
            .padding(EcrinSpacing.xl)
        }
    }
}

// MARK: - Step 3: Send
private struct GiftStep3Send: View {
    @ObservedObject var viewModel: GiftViewModel
    let currentUser: User

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                Text(L10n.GiftUI.readyToGift)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Final preview
                if let jewelry = viewModel.selectedJewelry {
                    GiftCardPreview(
                        jewelry: jewelry,
                        tryOnImage: viewModel.selectedTryOnImage,
                        message: viewModel.message,
                        occasion: viewModel.occasion
                    )
                    .aspectRatio(3/4, contentMode: .fit)
                }

                // Info
                GlassCard(cornerRadius: 14) {
                    HStack(spacing: EcrinSpacing.md) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(EcrinColor.gold)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.GiftUI.linkValid30Days)
                                .font(EcrinFont.body)
                                .foregroundStyle(EcrinColor.textPrimary)
                            Text(L10n.GiftUI.recipientCanTryAR)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                        }
                    }
                    .padding(EcrinSpacing.md)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(EcrinFont.caption)
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                // Create link CTA
                GoldButton(
                    title: viewModel.isCreatingLink ? "Création…" : "Créer le lien magique ✨"
                ) {
                    Task { await viewModel.createGiftLink(fromUser: currentUser) }
                }
                .disabled(viewModel.isCreatingLink)
                .overlay {
                    if viewModel.isCreatingLink {
                        ProgressView()
                            .tint(EcrinColor.background)
                    }
                }

                GhostButton(title: L10n.Common.previous) { viewModel.previous() }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.top, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.xxl)
        }
    }
}

// MARK: - Share Sheet
private struct GiftShareSheet: View {
    let url: URL
    let gift: GiftCard?
    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var copied = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                // Handle
                Capsule()
                    .fill(EcrinColor.glassStroke)
                    .frame(width: 40, height: 4)
                    .padding(.top, EcrinSpacing.md)

                // Success icon
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(EcrinColor.gold)
                }
                .padding(.top, EcrinSpacing.sm)

                VStack(spacing: EcrinSpacing.sm) {
                    Text(L10n.GiftUI.linkCreated)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(L10n.GiftUI.shareMagicLink)
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, EcrinSpacing.lg)
                }

                // URL display
                GlassCard(cornerRadius: 14) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(EcrinColor.gold)
                        Text(url.absoluteString)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(EcrinSpacing.md)
                }
                .padding(.horizontal, EcrinSpacing.lg)

                // Share options
                VStack(spacing: EcrinSpacing.sm) {
                    // System share (covers Messages, WhatsApp, Mail)
                    GoldButton(title: L10n.Common.share) {
                        showSystemShare = true
                    }

                    // Copy link
                    GhostButton(title: copied ? "Lien copié ✓" : "Copier le lien") {
                        UIPasteboard.general.string = url.absoluteString
                        withAnimation { copied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { copied = false }
                        }
                    }
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showSystemShare) {
            SystemShareSheet(items: [url])
        }
    }
}

// MARK: - System Share Sheet Wrapper
private struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
