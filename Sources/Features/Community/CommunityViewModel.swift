import SwiftUI

@MainActor
final class CommunityViewModel: ObservableObject {

    // MARK: - Published State

    @Published var posts: [CommunityPost] = []
    @Published var challenges: [CommunityChallenge] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading: Bool = false
    @Published var selectedTab: CommunityTab = .feed
    @Published var activeChallenge: CommunityChallenge?
    @Published var currentUserRank: Int = 7
    /// Toast affiché après une action (ex : "Vous avez rejoint le défi")
    @Published var toastMessage: String? = nil
    /// Identifie le challenge à ouvrir après confirmation (pour navigation vers QuickTryOn)
    @Published var pendingChallengeForTryOn: CommunityChallenge? = nil

    // MARK: - Tab

    enum CommunityTab: String, CaseIterable {
        case feed       = "Feed"
        case challenges = "Défis"
        case top        = "Top"

        var iconName: String {
            switch self {
            case .feed:       return "rectangle.stack.fill"
            case .challenges: return "flame.fill"
            case .top:        return "trophy.fill"
            }
        }
    }

    // MARK: - Init

    init() {
        // Seed with samples immediately so the feed is never empty on first render.
        loadSampleData()
        // Then replace with REAL Moniattitude jewelry + live posts asynchronously.
        Task {
            await loadDynamicSamplesFromMoniattitude()
            await refreshFeed()
        }
    }

    // MARK: - Data Loading

    /// Populates non-post state from bundled samples (challenges, leaderboard).
    private func loadSampleData() {
        challenges = CommunityChallenge.samples
        leaderboard = LeaderboardEntry.samples
        activeChallenge = challenges.first
        if posts.isEmpty {
            posts = CommunityPost.samples
        }
    }

    /// Charge les vrais bijoux Moniattitude (avec leurs vraies image_url) et génère
    /// des posts samples cohérents : chaque post montre le VRAI bijou + caption qui
    /// mentionne son nom réel. Garantit que photo = description.
    private func loadDynamicSamplesFromMoniattitude() async {
        do {
            let raw = try await SupabaseService.shared.fetchJewelryCatalog()
            let withImages = raw
                .filter { $0.imageURL != nil && !($0.imageURL ?? "").isEmpty }
                .map(\.asJewelryItem)
            if withImages.isEmpty { return }
            posts = CommunityPost.buildDynamicSamples(from: withImages)
        } catch {
            // Fallback REST si SDK échoue
            if let raw = try? await SupabaseService.shared.fetchJewelryCatalogViaREST() {
                let withImages = raw
                    .filter { $0.imageURL != nil && !($0.imageURL ?? "").isEmpty }
                    .map(\.asJewelryItem)
                if !withImages.isEmpty {
                    posts = CommunityPost.buildDynamicSamples(from: withImages)
                }
            }
        }
    }

    // MARK: - Actions

    func refreshFeed() async {
        isLoading = true
        // Fetch real user posts from Supabase; fall back to dynamic Moniattitude samples.
        let fetched = await SupabaseService.shared.fetchCommunityPosts()
        if !fetched.isEmpty {
            posts = fetched
        } else if posts.isEmpty {
            posts = CommunityPost.samples
        }
        isLoading = false
    }

    func toggleLike(post: CommunityPost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let current = posts[index]
        let newLiked = !current.isLiked
        let delta = newLiked ? 1 : -1
        // Optimistic local update.
        posts[index] = CommunityPost(
            id: current.id,
            author: current.author,
            jewelry: current.jewelry,
            tryOnImage: current.tryOnImage,
            imageURL: current.imageURL,
            location: current.location,
            caption: current.caption,
            likes: current.likes + delta,
            comments: current.comments,
            isLiked: newLiked,
            challenge: current.challenge,
            tags: current.tags,
            createdAt: current.createdAt
        )
        // Persist asynchronously — fire-and-forget.
        let postId = current.id
        Task.detached { await SupabaseService.shared.setPostLike(postId: postId, liked: newLiked) }
    }

    // MARK: - Challenge actions

    /// Rejoint un défi (ou le quitte si déjà inscrit).
    /// Met à jour participantCount et déclenche un toast de confirmation.
    func toggleParticipation(in challenge: CommunityChallenge) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        var updated = challenges[index]
        updated.isParticipating.toggle()
        updated.participantCount += updated.isParticipating ? 1 : -1
        challenges[index] = updated

        // Synchroniser activeChallenge si c'est le même défi
        if activeChallenge?.id == challenge.id {
            activeChallenge = updated
        }

        // Toast feedback
        if updated.isParticipating {
            toastMessage = "✓ Inscrite au défi « \(updated.title) »"
        } else {
            toastMessage = "Inscription retirée du défi"
        }

        // Auto-dismiss après 2,5s
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.toastMessage != nil { self.toastMessage = nil }
        }
    }

    /// Indique qu'on veut lancer un essayage dans le contexte d'un défi.
    /// Sera observé par la vue racine pour ouvrir QuickTryOn (à brancher au routeur).
    func startTryOnForChallenge(_ challenge: CommunityChallenge) {
        pendingChallengeForTryOn = challenge
    }

    func clearPendingChallenge() {
        pendingChallengeForTryOn = nil
    }

    func timeAgo(from date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        switch interval {
        case 0..<60:      return "A l'instant"
        case 60..<3600:   return "\(Int(interval / 60))min"
        case 3600..<86400: return "\(Int(interval / 3600))h"
        default:          return "\(Int(interval / 86400))j"
        }
    }

    func countdown(to date: Date) -> String {
        let remaining = date.timeIntervalSince(.now)
        guard remaining > 0 else { return "Terminé" }
        let days = Int(remaining / 86400)
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
        if days > 0 { return "\(days)j \(hours)h" }
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}
