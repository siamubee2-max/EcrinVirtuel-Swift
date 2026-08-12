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
    /// Composeur de post (bouton « Partager » des stories).
    @Published var showCompose: Bool = false
    /// id `users` (table profils) de l'utilisateur courant — pour détecter
    /// ses propres posts (post.author.id porte users.id, pas l'auth uid).
    @Published var currentUserRowID: UUID? = nil

    /// Posts masqués localement (signalés/masqués par l'utilisateur) —
    /// persistés pour que le masquage survive au relaunch (guideline UGC).
    private static let hiddenPostsKey = "ecrin_hidden_post_ids"
    private var hiddenPostIDs: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: hiddenPostsKey) ?? []) {
        didSet {
            UserDefaults.standard.set(Array(hiddenPostIDs), forKey: Self.hiddenPostsKey)
        }
    }

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
            posts = fetched.filter { !hiddenPostIDs.contains($0.id.uuidString) }
        } else if posts.isEmpty {
            posts = CommunityPost.samples
        }
        if currentUserRowID == nil,
           let authId = try? await SupabaseService.shared.auth.session.user.id.uuidString,
           let rowId = try? await SupabaseService.shared.resolveUsersRowID(authId: authId) {
            currentUserRowID = UUID(uuidString: rowId)
        }
        isLoading = false
    }

    // MARK: - Publication

    /// Publie un post (image hébergée best-effort) puis rafraîchit le feed.
    /// Retourne false si la publication a échoué (le composeur reste ouvert).
    func createPost(jewelry: JewelryItem, image: UIImage?, caption: String, author: User) async -> Bool {
        var imageURL: String?
        if let jpeg = image?.jpegData(compressionQuality: 0.8) {
            // Best-effort : sans bucket `community-posts` (ou hors ligne),
            // le post part sans image plutôt que d'échouer entièrement.
            imageURL = try? await SupabaseService.shared.uploadCommunityImage(jpeg)
        }
        do {
            try await SupabaseService.shared.createCommunityPost(
                jewelry: jewelry,
                imageURL: imageURL,
                location: nil,
                caption: caption,
                challenge: nil,
                tags: [],
                author: author
            )
        } catch {
            return false
        }
        GamingService.shared.record(.lookShared)
        await refreshFeed()
        showToast("Votre look est publié ✨")
        return true
    }

    /// Affiche un toast auto-fermant (même mécanique que les défis).
    func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.toastMessage == message { self.toastMessage = nil }
        }
    }

    // MARK: - Modération (guideline UGC 1.2)

    func isOwnPost(_ post: CommunityPost) -> Bool {
        guard let rowId = currentUserRowID else { return false }
        return post.author.id == rowId
    }

    /// Signale un contenu : masqué immédiatement pour l'utilisateur (persisté)
    /// + événement de monitoring pour la revue côté équipe.
    func report(post: CommunityPost) {
        hiddenPostIDs.insert(post.id.uuidString)
        posts.removeAll { $0.id == post.id }
        showToast("Merci — ce contenu sera examiné par notre équipe.")
        Task.detached {
            await SupabaseService.shared.insertMonitoringEvent(
                type: "community_post_reported",
                productId: nil,
                domain: "community",
                code: 0,
                message: post.id.uuidString
            )
        }
    }

    /// Masque un contenu sans le signaler.
    func hide(post: CommunityPost) {
        hiddenPostIDs.insert(post.id.uuidString)
        posts.removeAll { $0.id == post.id }
    }

    /// Supprime un de ses propres posts (RLS garantit la propriété côté serveur).
    func deletePost(_ post: CommunityPost) {
        posts.removeAll { $0.id == post.id }
        Task { await SupabaseService.shared.deleteCommunityPost(id: post.id) }
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
