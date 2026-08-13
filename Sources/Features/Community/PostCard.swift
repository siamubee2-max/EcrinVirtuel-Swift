import SwiftUI

// MARK: - Post Card
// Représente UN ESSAYAGE VIRTUEL partagé par une utilisatrice.
// Le sujet du post = le bijou essayé virtuellement (pas un portrait random).
// Layout : header auteur + cadre "essayage virtuel" autour du bijou + actions + témoignage.

struct PostCard: View {
    let post: CommunityPost
    let onLike: () -> Void
    // Modération UGC (guideline 1.2) — défauts nil pour ne pas casser les
    // usages qui n'affichent pas le menu.
    var isOwnPost: Bool = false
    var onReport: (() -> Void)? = nil
    var onHide: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @State private var showReportConfirmation = false
    @State private var showDeleteConfirmation = false

    @State private var showHeartBurst: Bool = false
    @State private var heartScale: CGFloat = 0
    @State private var heartOpacity: Double = 0
    @State private var showTryOn: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            authorHeader
            tryOnFrame
            actionsBar
            captionBlock
        }
        .background(EcrinColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        }
        .sheet(isPresented: $showTryOn) {
            QuickTryOnView(
                preselectedItem: .wardrobe(post.jewelry.asFashionItem),
                preselectedMode: .jewelsOnly
            )
            .environment(appState)
            .environment(ClothingCatalogService.shared)
            .presentationDetents([.large])
        }
    }

    // MARK: - Header auteur

    private var authorHeader: some View {
        HStack(spacing: EcrinSpacing.sm) {
            // Avatar — initiales sur dégradé doré
            Circle()
                .fill(
                    LinearGradient(
                        colors: [EcrinColor.gold.opacity(0.55), EcrinColor.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay {
                    Text(authorInitials)
                        .font(EcrinFont.sans(13, weight: .semibold))
                        .foregroundStyle(EcrinColor.background)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.author.displayName ?? post.author.email)
                    .font(EcrinFont.sans(13, weight: .semibold))
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(1)

                // Sous-titre : "a essayé virtuellement · il y a 2h · Paris"
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(EcrinColor.gold)
                    Text(L10n.CommunityUI.triedVirtually)
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.textSecondary)
                    if let location = post.location {
                        Text("·")
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.textMuted)
                        Text(location)
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                }
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Challenge badge
            if let challenge = post.challenge {
                Text(challenge.hashtag)
                    .font(EcrinFont.label)
                    .kerning(0.5)
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(EcrinColor.gold.opacity(0.12))
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            // Modération : signaler/masquer (tous), supprimer (ses posts)
            if onReport != nil || onHide != nil || onDelete != nil {
                Menu {
                    if isOwnPost, onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label(L10n.CommunityUI.deleteMyPost, systemImage: "trash")
                        }
                    } else {
                        if onReport != nil {
                            Button(role: .destructive) {
                                showReportConfirmation = true
                            } label: {
                                Label(L10n.CommunityUI.reportContent, systemImage: "exclamationmark.bubble")
                            }
                        }
                        if let onHide {
                            Button {
                                onHide()
                            } label: {
                                Label(L10n.CommunityUI.hide, systemImage: "eye.slash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(EcrinColor.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.CommunityUI.postOptions)
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm + 4)
        .confirmationDialog(
            L10n.CommunityUI.reportContentConfirm,
            isPresented: $showReportConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.CommunityUI.report, role: .destructive) { onReport?() }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.CommunityUI.reportReviewNotice)
        }
        .confirmationDialog(
            L10n.CommunityUI.deletePostConfirm,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.delete, role: .destructive) { onDelete?() }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
    }

    // MARK: - Cadre "essayage virtuel" autour du bijou

    /// Le hero du post = LE BIJOU essayé, mis dans un cadre élégant qui dit
    /// clairement "ESSAYAGE VIRTUEL". C'est le sujet de la publication.
    private var tryOnFrame: some View {
        ZStack {
            // Background sombre élégant (sépia doré)
            LinearGradient(
                colors: [
                    EcrinColor.background,
                    Color(hex: "#1A1410"),
                    EcrinColor.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Cadre intérieur : la photo du bijou
            jewelryFocus

            // Coin top-gauche : badge ESSAYAGE VIRTUEL
            VStack {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(EcrinColor.gold)
                        Text(L10n.CommunityUI.virtualTryOnCaps)
                            .font(EcrinFont.label)
                            .kerning(1.8)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.55), in: Capsule())
                    .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.45), lineWidth: 0.6))
                    Spacer()
                }
                .padding(EcrinSpacing.sm)
                Spacer()
            }

            // Bas : nom du bijou + matériau
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: post.jewelry.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(EcrinColor.gold)
                        Text(post.jewelry.name.uppercased())
                            .font(EcrinFont.label)
                            .kerning(2.0)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Text(post.jewelry.material)
                        .font(EcrinFont.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.vertical, EcrinSpacing.sm + 2)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Double-tap heart burst
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(EcrinColor.gold)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
            }
        }
        .frame(height: 360)
        .clipped()
        .onTapGesture(count: 2) { handleDoubleTap() }
    }

    /// Affichage du bijou — VRAIE photo Moniattitude si disponible,
    /// sinon vitrine graphique élégante (icône stylisée) en fallback.
    @ViewBuilder
    private var jewelryFocus: some View {
        ZStack {
            // Glow doré subtil derrière le cadre
            Circle()
                .fill(EcrinColor.gold.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 50)

            if let url = post.jewelry.imageURL {
                // VRAIE photo Moniattitude — affichage en grand carré encadré
                realJewelryPhotoCard(url: url)
            } else {
                // Fallback graphique élégant si pas d'image réelle
                graphicVitrineCard
            }
        }
    }

    /// Carte photo réelle du bijou (Moniattitude) — carré 240×240 encadré or.
    @ViewBuilder
    private func realJewelryPhotoCard(url: URL) -> some View {
        ZStack {
            // Fond noir au cas où la photo aurait des bords transparents
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    EcrinColor.gold.opacity(0.7),
                                    EcrinColor.gold.opacity(0.3),
                                    EcrinColor.gold.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFit()
                        .padding(EcrinSpacing.sm)
                case .empty:
                    ProgressView().tint(EcrinColor.gold)
                case .failure:
                    graphicVitrineCard
                @unknown default:
                    graphicVitrineCard
                }
            }
        }
        .frame(width: 240, height: 240)
        .shadow(color: EcrinColor.gold.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    /// Vitrine graphique (fallback) : icône stylisée + matériau.
    private var graphicVitrineCard: some View {
        ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#1A1410"),
                                Color(hex: "#0F0B08"),
                                Color(hex: "#1A1410")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        EcrinColor.gold.opacity(0.6),
                                        EcrinColor.gold.opacity(0.25),
                                        EcrinColor.gold.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )

                // Composition centrale : icône bijou + matériau
                VStack(spacing: EcrinSpacing.md) {
                    // Petit séparateur supérieur
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(EcrinColor.gold.opacity(0.5))
                            .frame(width: 24, height: 0.6)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(EcrinColor.gold)
                        Rectangle()
                            .fill(EcrinColor.gold.opacity(0.5))
                            .frame(width: 24, height: 0.6)
                    }

                    Image(systemName: post.jewelry.icon)
                        .font(.system(size: 84, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [EcrinColor.goldLight, EcrinColor.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: EcrinColor.gold.opacity(0.4), radius: 12, x: 0, y: 4)

                    // Matériau en petit, doré
                    Text(jewelryShortMaterial.uppercased())
                        .font(EcrinFont.label)
                        .kerning(2.5)
                        .foregroundStyle(EcrinColor.gold.opacity(0.75))
                        .lineLimit(1)
                        .padding(.horizontal, EcrinSpacing.md)

                    // Petit séparateur inférieur
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(EcrinColor.gold.opacity(0.5))
                            .frame(width: 24, height: 0.6)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(EcrinColor.gold)
                        Rectangle()
                            .fill(EcrinColor.gold.opacity(0.5))
                            .frame(width: 24, height: 0.6)
                    }
                }
                .padding(EcrinSpacing.lg)
            }
            .frame(width: 240, height: 240)
            .shadow(color: EcrinColor.gold.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    /// Matériau abrégé pour l'affichage en vitrine (1ère partie avant le ·)
    private var jewelryShortMaterial: String {
        let parts = post.jewelry.material.components(separatedBy: "·")
        return parts.first?.trimmingCharacters(in: .whitespaces) ?? post.jewelry.material
    }

    // MARK: - Actions bar — focus sur "Essayer aussi"

    private var actionsBar: some View {
        HStack(spacing: EcrinSpacing.lg) {
            // Like
            Button {
                withAnimation(EcrinAnimation.springSnap) { onLike() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(post.isLiked ? EcrinColor.gold : EcrinColor.textSecondary)
                    Text("\(post.likes)")
                        .font(EcrinFont.sans(12, weight: .medium))
                        .foregroundStyle(EcrinColor.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Comment
            HStack(spacing: 5) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 17))
                    .foregroundStyle(EcrinColor.textSecondary)
                Text("\(post.comments)")
                    .font(EcrinFont.sans(12, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
            }

            Spacer()

            // CTA principal : ESSAYER AUSSI — appel à l'action de l'app
            Button { showTryOn = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.CommunityUI.tryItToo)
                        .font(EcrinFont.sans(12, weight: .semibold))
                        .kerning(0.3)
                }
                .foregroundStyle(EcrinColor.background)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(EcrinColor.gold)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.CommunityUI.tryJewelVirtually)

            // Share
            Image(systemName: "paperplane")
                .font(.system(size: 17))
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm + 4)
    }

    // MARK: - Témoignage

    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Caption avec attribution
            HStack(alignment: .top, spacing: 5) {
                Text(post.author.displayName ?? "")
                    .font(EcrinFont.sans(13, weight: .semibold))
                    .foregroundStyle(EcrinColor.textPrimary)
                Text(post.caption)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
            .lineLimit(3)

            // Tags + heure
            HStack(spacing: 6) {
                ForEach(post.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.gold.opacity(0.7))
                }
                Spacer()
                Text(timeAgo(from: post.createdAt))
                    .font(EcrinFont.label)
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm + 4)
    }

    // MARK: - Helpers

    private var authorInitials: String {
        let name = post.author.displayName ?? post.author.email
        let parts = name.components(separatedBy: .whitespacesAndNewlines)
        if parts.count >= 2 {
            return String((parts[0].first ?? "?")) + String((parts[1].first ?? "?"))
        }
        return String(name.prefix(2)).uppercased()
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        switch interval {
        case 0..<60:       return "À l'instant"
        case 60..<3600:    return "il y a \(Int(interval / 60))min"
        case 3600..<86400: return "il y a \(Int(interval / 3600))h"
        default:           return "il y a \(Int(interval / 86400))j"
        }
    }

    private func handleDoubleTap() {
        if !post.isLiked { onLike() }
        showHeartBurst = true
        heartScale = 0.3
        heartOpacity = 1

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            heartScale = 1.2
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            heartScale = 0.8
            heartOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showHeartBurst = false
        }
    }
}
