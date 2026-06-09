import SwiftUI

// MARK: - Wedding Share View (Bottom Sheet)

struct WeddingShareView: View {
    @ObservedObject var viewModel: WeddingViewModel
    @State private var newEmail = ""
    @State private var emailError: String?
    @State private var showActivitySheet = false
    @FocusState private var emailFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(EcrinColor.glassStroke)
                    .frame(width: 40, height: 4)
                    .padding(.top, EcrinSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EcrinSpacing.xl) {
                        headerSection
                        lookPreviewSection
                        addEmailSection
                        bridesmaidListSection
                        sendSection
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.xxl)
                }
            }
        }
        .sheet(isPresented: $showActivitySheet) {
            ActivitySheet(items: [buildShareMessage()])
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: EcrinSpacing.sm) {
            Text("DEMOISELLES D'HONNEUR")
                .font(EcrinFont.label)
                .kerning(3)
                .foregroundStyle(EcrinColor.gold)
                .padding(.top, EcrinSpacing.sm)

            Text("Partagez votre look")
                .font(EcrinFont.sectionHead)
                .foregroundStyle(EcrinColor.textPrimary)

            Text("Vos demoiselles pourront voir votre sélection\net essayer chaque bijou sur elles-mêmes.")
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Look preview (chips of all jewelry pieces)

    @ViewBuilder
    private var lookPreviewSection: some View {
        if !viewModel.weddingLook.pieces.isEmpty {
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                Text("VOTRE SÉLECTION")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)

                GlassCard(cornerRadius: 18) {
                    VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                        // All pieces as chips
                        let sortedPieces = viewModel.weddingLook.pieces
                            .sorted(by: { $0.slotType.sortOrder < $1.slotType.sortOrder })

                        FlexibleChipLayout(spacing: EcrinSpacing.sm) {
                            ForEach(sortedPieces) { piece in
                                JewelryChip(piece: piece)
                            }
                        }
                    }
                    .padding(EcrinSpacing.md)
                }
            }
        }
    }

    // MARK: - Add email

    private var addEmailSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("AJOUTER PAR EMAIL")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            GlassCard(cornerRadius: 16) {
                HStack(spacing: EcrinSpacing.md) {
                    Image(systemName: "envelope")
                        .font(.system(size: 16, weight: .thin))
                        .foregroundStyle(EcrinColor.gold.opacity(0.7))

                    TextField("email@exemple.com", text: $newEmail)
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($emailFocused)
                        .submitLabel(.done)
                        .onSubmit { addBridesmaid() }

                    if !newEmail.isEmpty {
                        Button(action: addBridesmaid) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(EcrinColor.gold)
                        }
                    }
                }
                .padding(EcrinSpacing.md)
            }

            if let error = emailError {
                Text(error)
                    .font(EcrinFont.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Bridesmaid list

    @ViewBuilder
    private var bridesmaidListSection: some View {
        if !viewModel.weddingLook.bridesmaidEmails.isEmpty {
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                Text("INVITÉES (\(viewModel.weddingLook.bridesmaidEmails.count))")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)

                VStack(spacing: EcrinSpacing.sm) {
                    ForEach(viewModel.weddingLook.bridesmaidEmails, id: \.self) { email in
                        BridesmaidRow(email: email) {
                            withAnimation(EcrinAnimation.springSnap) {
                                viewModel.removeBridesmaid(email: email)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Send section

    private var sendSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            GoldButton(title: "Envoyer les invitations") {
                showActivitySheet = true
            }
            .disabled(viewModel.weddingLook.bridesmaidEmails.isEmpty)
            .opacity(viewModel.weddingLook.bridesmaidEmails.isEmpty ? 0.4 : 1.0)

            if !viewModel.weddingLook.bridesmaidEmails.isEmpty {
                Text("Voici mon look mariage, vous pouvez essayer chaque bijou !")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private func addBridesmaid() {
        let email = newEmail.trimmingCharacters(in: .whitespaces).lowercased()
        guard !email.isEmpty else { return }
        guard email.contains("@") && email.contains(".") else {
            emailError = "Adresse email invalide"
            return
        }
        guard !viewModel.weddingLook.bridesmaidEmails.contains(email) else {
            emailError = "Cette adresse est déjà ajoutée"
            return
        }
        emailError = nil
        withAnimation(EcrinAnimation.springSnap) {
            viewModel.addBridesmaid(email: email)
        }
        newEmail = ""
        emailFocused = false
    }

    private func buildShareMessage() -> String {
        let names = viewModel.weddingLook.bridesmaidEmails.joined(separator: ", ")
        let url = viewModel.shareURL
        let pieceNames = viewModel.weddingLook.pieces
            .sorted(by: { $0.slotType.sortOrder < $1.slotType.sortOrder })
            .map { "\($0.slotType.rawValue) : \($0.jewelry.name)" }
            .joined(separator: "\n")

        return """
Bonjour \(names) !

Découvrez mon look de mariage sur L'Écrin Virtuel et essayez chaque bijou :

\(pieceNames.isEmpty ? "" : pieceNames + "\n\n")Lien : \(url)
"""
    }
}

// MARK: - Jewelry Chip

private struct JewelryChip: View {
    let piece: WeddingPiece

    var body: some View {
        HStack(spacing: EcrinSpacing.xs) {
            Image(systemName: piece.jewelry.icon)
                .font(.system(size: 11, weight: .thin))
                .foregroundStyle(EcrinColor.gold)

            VStack(alignment: .leading, spacing: 0) {
                Text(piece.slotType.rawValue)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(EcrinColor.gold.opacity(0.7))
                    .kerning(0.5)
                    .textCase(.uppercase)
                Text(piece.jewelry.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
        }
        .padding(.horizontal, EcrinSpacing.sm)
        .padding(.vertical, EcrinSpacing.xs)
        .background(EcrinColor.gold.opacity(0.08))
        .overlay {
            Capsule()
                .strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 0.5)
        }
        .clipShape(Capsule())
    }
}

// MARK: - Flexible Chip Layout (wrapping)

private struct FlexibleChipLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        _ = maxWidth
    }
}

// MARK: - Bridesmaid Row

private struct BridesmaidRow: View {
    let email: String
    let onRemove: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 14) {
            HStack(spacing: EcrinSpacing.md) {
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text(String(email.prefix(1)).uppercased())
                        .font(EcrinFont.serif(16, weight: .regular))
                        .foregroundStyle(EcrinColor.gold)
                }

                Text(email)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(EcrinColor.textMuted)
                        .padding(6)
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
        }
    }
}

// MARK: - UIActivity wrapper

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
