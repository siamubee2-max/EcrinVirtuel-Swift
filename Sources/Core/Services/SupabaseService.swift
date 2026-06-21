import Foundation
import Supabase

// MARK: - Client singleton
final class SupabaseService: @unchecked Sendable {

    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        guard !Secrets.supabaseURL.isEmpty, let url = URL(string: Secrets.supabaseURL) else {
            fatalError("SUPABASE_URL invalide ou manquante — vérifier Info.plist / Secrets.xcconfig")
        }
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Secrets.supabaseAnonKey
        )
    }
}

// MARK: - Tables (même schéma que l'ancienne app React Native)
extension SupabaseService {

    // Tables existantes
    static let jewelry        = "jewelry"
    static let bodyParts      = "body_parts"
    static let tryOnSessions  = "try_on_sessions"

    // Nouvelles tables Swift (à créer via migration)
    static let users            = "users"
    static let savedLooks       = "saved_looks"
    static let weddingLooks     = "wedding_looks"
    static let giftCards        = "gift_cards"
    static let communityPosts   = "community_posts"
    static let partnerBrands         = "partner_brands"
    static let partnerApplications   = "partner_applications"
    static let userQuotas            = "user_quotas"
    static let monitoringEvents      = "monitoring_events"
    static let clothingCatalog  = "clothing_catalog"
    static let wardrobeItems    = "wardrobe_items"
    static let gamingProfiles   = "gaming_profiles"
}

// MARK: - Auth
extension SupabaseService {

    var auth: AuthClient { client.auth }

    /// Vrai si une session Supabase Auth valide existe (requis pour tryon-generate).
    func hasValidSession() async -> Bool {
        (try? await auth.session) != nil
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let session = try await auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        return User(
            id: UUID(uuidString: session.user.id.uuidString) ?? UUID(),
            email: session.user.email ?? "",
            displayName: session.user.userMetadata["full_name"]?.value as? String
        )
    }

    /// Envoie un code OTP à 6 chiffres par email (pas de lien magique).
    /// `shouldCreateUser: true` crée le compte à la 1re connexion.
    func signInWithEmail(_ email: String) async throws {
        try await auth.signInWithOTP(
            email: email,
            shouldCreateUser: true
        )
    }

    /// Vérifie le code OTP à 6 chiffres saisi par l'utilisateur et ouvre la session.
    /// C'est le flux mobile robuste : aucun deep-link ni redirect URL nécessaire.
    func verifyEmailOTP(email: String, code: String) async throws -> User {
        let response = try await auth.verifyOTP(
            email: email,
            token: code,
            type: .email
        )
        let sbUser = response.user
        return User(
            id: UUID(uuidString: sbUser.id.uuidString) ?? UUID(),
            email: sbUser.email ?? email,
            displayName: sbUser.userMetadata["full_name"]?.value as? String
        )
    }

    /// À appeler depuis l'App `onOpenURL` pour finaliser la session
    /// après tap sur le lien magique reçu par email.
    /// Retourne le `User` connecté si la session a été acceptée, sinon `nil`.
    func handleDeepLink(_ url: URL) async -> User? {
        do {
            let session = try await auth.session(from: url)
            return User(
                id: UUID(uuidString: session.user.id.uuidString) ?? UUID(),
                email: session.user.email ?? "",
                displayName: session.user.userMetadata["full_name"]?.value as? String
            )
        } catch {
            await SupabaseService.shared.insertMonitoringEvent(
                type: "deep_link_error",
                productId: nil,
                domain: (error as NSError).domain,
                code: (error as NSError).code,
                message: error.localizedDescription
            )
            return nil
        }
    }

    func signOut() async throws {
        try await auth.signOut()
    }

    func currentUser() async -> User? {
        guard let session = try? await auth.session else { return nil }
        let authId = session.user.id.uuidString
        var user = User(
            id: UUID(uuidString: authId) ?? UUID(),
            email: session.user.email ?? "",
            displayName: session.user.userMetadata["full_name"]?.value as? String
        )
        if let gender = try? await fetchPreferredGender(authId: authId) {
            user.preferredGender = gender
        }
        return user
    }

    /// Lit `preferred_gender` depuis `users` (id = auth.uid()).
    func fetchPreferredGender(authId: String) async throws -> ClothingGender? {
        struct Row: Decodable {
            let preferred_gender: String?
        }
        let rows: [Row] = try await client
            .from(Self.users)
            .select("preferred_gender")
            .eq("id", value: authId)
            .limit(1)
            .execute()
            .value
        guard let raw = rows.first?.preferred_gender else { return nil }
        return ClothingGender(rawValue: raw)
    }

    /// Persiste le genre Look du Jour (upsert profil `users` par id = auth.uid()).
    func updatePreferredGender(_ gender: ClothingGender) async {
        guard let session = try? await auth.session else { return }
        let authId = session.user.id.uuidString
        let email = session.user.email
        let displayName = session.user.userMetadata["full_name"]?.value as? String

        struct UpsertRow: Encodable {
            let id: String
            let email: String?
            let display_name: String?
            let preferred_gender: String
        }

        let row = UpsertRow(
            id: authId,
            email: email,
            display_name: displayName,
            preferred_gender: gender.rawValue
        )

        _ = try? await client
            .from(Self.users)
            .upsert(row, onConflict: "id")
            .execute()
    }

    // MARK: - Quotas & Crédits

    func fetchRemainingCredits() async throws -> Int {
        guard let userId = try? await auth.session.user.id.uuidString else {
            throw URLError(.userAuthenticationRequired)
        }
        struct Quota: Decodable { let generations_remaining: Int }
        let quota: Quota = try await client
            .from(Self.userQuotas)
            .select("generations_remaining")
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        return quota.generations_remaining
    }

    /// Appelle l'Edge Function `credit-generations` après un achat RevenueCat réussi.
    /// Retourne le nouveau total de crédits.
    func creditGenerations(productId: String, transactionId: String) async throws -> Int {
        struct CreditRequest: Encodable {
            let product_id: String
            let transaction_id: String
        }
        struct CreditResponse: Decodable {
            let new_total: Int
        }
        let response: CreditResponse = try await client.functions.invoke(
            "credit-generations",
            options: FunctionInvokeOptions(body: CreditRequest(
                product_id: productId,
                transaction_id: transactionId
            ))
        )
        return response.new_total
    }

    /// Suppression complète du compte (obligatoire Apple Guideline 5.1.1(v)).
    /// Supprime les données utilisateur dans Supabase puis le compte auth.
    func deleteAccount() async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }

        // Supprimer toutes les données utilisateur associées à user_id / auth_id.
        // Ordre : dépendants en premier, profil en dernier.
        try await client.from(Self.savedLooks).delete().eq("user_id", value: userId).execute()
        try await client.from(Self.tryOnSessions).delete().eq("user_id", value: userId).execute()
        try await client.from(Self.communityPosts).delete().eq("user_id", value: userId).execute()
        try await client.from(Self.wardrobeItems).delete().eq("user_id", value: userId).execute()
        try await client.from(Self.userQuotas).delete().eq("user_id", value: userId).execute()
        try await client.from(Self.users).delete().eq("id", value: userId).execute()

        // Supprimer le compte auth (nécessite un Edge Function avec service_role)
        try await client.functions.invoke(
            "delete-user-account",
            options: FunctionInvokeOptions(body: ["user_id": userId])
        )
        try await auth.signOut()
    }
}

// MARK: - Monitoring (fire-and-forget event logger)

extension SupabaseService {

    private struct MonitoringRow: Encodable {
        let event_type: String
        let product_id: String?
        let error_domain: String
        let error_code: Int
        let error_message: String
        let platform: String = "ios"
        let app_version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build_number: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Inserts a monitoring event — called from Task.detached, never throws.
    func insertMonitoringEvent(type: String, productId: String?, domain: String, code: Int, message: String) async {
        let row = MonitoringRow(event_type: type, product_id: productId,
                                error_domain: domain, error_code: code, error_message: message)
        _ = try? await client.from(Self.monitoringEvents).insert(row).execute()
    }
}

final class MonitoringService: @unchecked Sendable {
    static let shared = MonitoringService()
    private init() {}

    func recordPurchaseError(_ error: Error, productId: String) {
        let ns = error as NSError
        let (d, c, m) = (ns.domain, ns.code, error.localizedDescription)
        Task.detached { await SupabaseService.shared.insertMonitoringEvent(type: "purchase_error",    productId: productId, domain: d, code: c, message: m) }
    }

    func recordRestoreError(_ error: Error) {
        let ns = error as NSError
        let (d, c, m) = (ns.domain, ns.code, error.localizedDescription)
        Task.detached { await SupabaseService.shared.insertMonitoringEvent(type: "restore_error",     productId: nil,       domain: d, code: c, message: m) }
    }

    func recordEntitlementMismatch(productId: String) {
        Task.detached { await SupabaseService.shared.insertMonitoringEvent(type: "entitlement_mismatch", productId: productId, domain: "Paywall", code: -1, message: "Purchase succeeded but premium entitlement not active") }
    }
}

// MARK: - Jewelry catalog (tables existantes)
extension SupabaseService {

    func fetchJewelryCatalog() async throws -> [SupabaseJewelry] {
        try await client
            .from(Self.jewelry)
            .select()
            .order("type")
            .order("name")
            .execute()
            .value
    }

    /// Fallback REST pour le catalogue bijoux (contourne les échecs SDK silencieux).
    func fetchJewelryCatalogViaREST() async throws -> [SupabaseJewelry] {
        guard !Secrets.supabaseURL.isEmpty, !Secrets.supabaseAnonKey.isEmpty else {
            throw URLError(.badURL)
        }
        var components = URLComponents(string: "\(Secrets.supabaseURL)/rest/v1/jewelry")!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "type.asc,name.asc"),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = try? await auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([SupabaseJewelry].self, from: data)
    }

    func saveTryOnSession(jewelryId: String, resultImageURL: String?) async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        try await client
            .from(Self.tryOnSessions)
            .insert([
                "jewelry_id": jewelryId,
                "user_id": userId,
                "result_image_url": resultImageURL ?? "",
                "created_at": ISO8601DateFormatter().string(from: .now)
            ])
            .execute()
    }

    func fetchTryOnHistory(limit: Int = 20) async throws -> [TryOnSession] {
        guard let userId = try? await auth.session.user.id.uuidString else { return [] }
        return try await client
            .from(Self.tryOnSessions)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}

// MARK: - Supabase response models (schéma existant)
struct SupabaseJewelry: Codable, Identifiable {
    let id: String
    let name: String
    let type: String          // earrings | necklace | bracelet | ring | anklet | brooch
    let metal: String?
    let gems: [String]?       // text[] en Postgres — DOIT être [String]?, pas String?
    let brand: String?
    let collection: String?
    let imageURL: String?
    let tags: [String]?
    let isFavorite: Bool?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, type, metal, gems, brand, collection, tags
        case imageURL     = "image_url"
        case isFavorite   = "is_favorite"
        case createdAt    = "created_at"
    }

    var asJewelryItem: JewelryItem {
        let gemsText = gems?.joined(separator: ", ")
        let material = [metal, gemsText].compactMap { $0 }.joined(separator: " · ")
        return JewelryItem(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            category: JewelryItem.JewelryCategory(rawValue: categoryLabel) ?? .necklace,
            imageURL: imageURL.flatMap { URL(string: $0) },
            icon: iconForType,
            material: material.isEmpty ? "" : material,
            prompt: "\(name) \(metal ?? "gold") jewelry"
        )
    }

    private var categoryLabel: String {
        switch type {
        case "earrings":  return "Boucles"
        case "necklace":  return "Collier"
        case "bracelet":  return "Bracelet"
        case "ring":      return "Bague"
        default:          return "Collier"
        }
    }

    private var iconForType: String {
        switch type {
        case "earrings":  return "oval.fill"
        case "necklace":  return "link"
        case "bracelet":  return "circle"
        case "ring":      return "circle.hexagongrid.fill"
        default:          return "diamond.fill"
        }
    }
}

struct TryOnSession: Codable, Identifiable {
    let id: String
    let jewelryId: String
    let userId: String
    let resultImageURL: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case jewelryId      = "jewelry_id"
        case userId         = "user_id"
        case resultImageURL = "result_image_url"
        case createdAt      = "created_at"
    }
}

// MARK: - Wardrobe (garde-robe cloud sync)

/// Row Supabase pour la table `wardrobe_items`.
/// Schéma prod exact (10 colonnes) : id, user_id, name, type, category, brand,
/// color, image_url, is_favorite, created_at.
/// `type` (NOT NULL) = `category` = FashionCategory.rawValue.
/// Les champs non persistés (subcategory, material, tags, tryOnPrompt, source,
/// price, purchaseURL) sont reconstruits avec des valeurs par défaut dans `asFashionItem`.
struct SupabaseWardrobeRow: Codable, Identifiable {
    let id: String
    let user_id: String
    let name: String
    let type: String       // NOT NULL — requis par le schéma prod
    let category: String
    let brand: String?
    let color: String?
    let image_url: String?
    let is_favorite: Bool
    let created_at: String

    var asFashionItem: FashionItem {
        let fashionCategory = FashionCategory(rawValue: category) ?? .top
        return FashionItem(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            category: fashionCategory,
            subcategory: nil,
            brand: brand,
            color: color,
            material: nil,
            imageURL: image_url.flatMap { URL(string: $0) },
            tags: [],
            tryOnPrompt: fashionCategory.defaultPrompt(name: name),
            source: .userPhoto,
            price: nil,
            purchaseURL: nil,
            isFavorite: is_favorite,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? .now
        )
    }
}

extension SupabaseService {

    /// Récupère tous les articles de la garde-robe de l'utilisateur connecté.
    func fetchWardrobeItems() async throws -> [FashionItem] {
        guard let userId = try? await auth.session.user.id.uuidString else { return [] }
        let rows: [SupabaseWardrobeRow] = try await client
            .from(Self.wardrobeItems)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map(\.asFashionItem)
    }

    /// Insère ou met à jour un article de garde-robe (upsert par `id`).
    func saveWardrobeItem(_ item: FashionItem) async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        let categoryValue = item.category.rawValue
        let row = SupabaseWardrobeRow(
            id: item.id.uuidString,
            user_id: userId,
            name: item.name,
            type: categoryValue,
            category: categoryValue,
            brand: item.brand,
            color: item.color,
            image_url: item.imageURL?.absoluteString,
            is_favorite: item.isFavorite,
            created_at: ISO8601DateFormatter().string(from: item.createdAt)
        )
        try await client
            .from(Self.wardrobeItems)
            .upsert(row, onConflict: "id")
            .execute()
    }

    /// Supprime un article de la garde-robe.
    func deleteWardrobeItem(id: UUID) async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        try await client
            .from(Self.wardrobeItems)
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Met à jour uniquement le flag `is_favorite` d'un article.
    func updateWardrobeFavorite(id: UUID, isFavorite: Bool) async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        struct FavoriteUpdate: Encodable {
            let is_favorite: Bool
        }
        let payload = FavoriteUpdate(is_favorite: isFavorite)
        try await client
            .from(Self.wardrobeItems)
            .update(payload)
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Supprime TOUS les articles de la garde-robe (utilisé par deleteAccount).
    func deleteAllWardrobeItems() async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        try await client
            .from(Self.wardrobeItems)
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }
}

// MARK: - Community Posts

/// Flat representation of a `community_posts` Supabase row.
/// Note: author_email was removed from the DB in migration 006 (PII — public table).
struct SupabaseCommunityPostRow: Decodable {
    let id: String
    let user_id: String
    let author_display_name: String
    let jewelry_name: String
    let jewelry_material: String
    let jewelry_category: String   // JewelryItem.JewelryCategory.rawValue
    let jewelry_icon: String
    let image_url: String?
    let location: String?
    let caption: String
    let likes: Int
    let comments: Int
    let challenge_hashtag: String?
    let challenge_title: String?
    let tags: [String]
    let created_at: String

    /// Maps the raw row to the app's `CommunityPost` model.
    func asCommunityPost(liked: Bool = false) -> CommunityPost {
        let category = JewelryItem.JewelryCategory(rawValue: jewelry_category) ?? .ring
        let jewelry = JewelryItem(
            id: UUID(),
            name: jewelry_name,
            category: category,
            imageURL: nil,
            icon: jewelry_icon,
            material: jewelry_material,
            prompt: ""
        )
        let author = User(
            id: UUID(uuidString: user_id) ?? UUID(),
            email: "",   // author_email removed from DB (migration 006 — PII fix)
            displayName: author_display_name
        )
        let challenge: CommunityChallenge? = challenge_hashtag.map { hashtag in
            CommunityChallenge(
                id: UUID(),
                title: challenge_title ?? hashtag,
                description: "",
                endDate: .distantFuture,
                participantCount: 0,
                prize: "",
                prizeIcon: "sparkles",
                hashtag: hashtag,
                coverImageName: "flame.fill"
            )
        }
        return CommunityPost(
            id: UUID(uuidString: id) ?? UUID(),
            author: author,
            jewelry: jewelry,
            tryOnImage: Data(),
            imageURL: image_url,
            location: location,
            caption: caption,
            likes: likes,
            comments: comments,
            isLiked: liked,
            challenge: challenge,
            tags: tags,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? .now
        )
    }
}

/// Payload for inserting a new community post.
/// Note: author_email intentionally omitted — removed in migration 006 (PII fix).
struct SupabaseCommunityPostInsert: Encodable {
    let id: String
    let user_id: String
    let author_display_name: String
    let jewelry_name: String
    let jewelry_material: String
    let jewelry_category: String
    let jewelry_icon: String
    let image_url: String?
    let location: String?
    let caption: String
    let challenge_hashtag: String?
    let challenge_title: String?
    let tags: [String]
    let created_at: String
}

extension SupabaseService {

    private static let postLikes = "post_likes"

    /// Fetches the most recent `limit` community posts, ordered newest-first.
    /// Returns `[]` on any error so the caller can fall back to sample data.
    func fetchCommunityPosts(limit: Int = 30) async -> [CommunityPost] {
        do {
            let rows: [SupabaseCommunityPostRow] = try await client
                .from(Self.communityPosts)
                .select("*")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Determine which posts the signed-in user has liked (best-effort).
            var likedIDs: Set<String> = []
            if let userId = try? await auth.session.user.id.uuidString {
                struct LikeRow: Decodable { let post_id: String }
                if let likes: [LikeRow] = try? await client
                    .from(Self.postLikes)
                    .select("post_id")
                    .eq("user_id", value: userId)
                    .execute()
                    .value {
                    likedIDs = Set(likes.map(\.post_id))
                }
            }

            return rows.map { $0.asCommunityPost(liked: likedIDs.contains($0.id)) }
        } catch {
            return []
        }
    }

    /// Persists a like toggle.  Fire-and-forget — does not throw.
    /// `liked: true` → upsert into post_likes; `liked: false` → delete.
    func setPostLike(postId: UUID, liked: Bool) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        if liked {
            struct LikeRow: Encodable { let post_id: String; let user_id: String }
            _ = try? await client
                .from(Self.postLikes)
                .upsert(LikeRow(post_id: postId.uuidString, user_id: userId))
                .execute()
        } else {
            _ = try? await client
                .from(Self.postLikes)
                .delete()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId)
                .execute()
        }
    }

    /// Inserts a new community post by the current signed-in user.
    func createCommunityPost(
        jewelry: JewelryItem,
        imageURL: String?,
        location: String?,
        caption: String,
        challenge: CommunityChallenge?,
        tags: [String],
        author: User
    ) async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        let row = SupabaseCommunityPostInsert(
            id: UUID().uuidString,
            user_id: userId,
            author_display_name: author.displayName ?? "Utilisateur",
            jewelry_name: jewelry.name,
            jewelry_material: jewelry.material,
            jewelry_category: jewelry.category.rawValue,
            jewelry_icon: jewelry.icon,
            image_url: imageURL,
            location: location,
            caption: caption,
            challenge_hashtag: challenge?.hashtag,
            challenge_title: challenge?.title,
            tags: tags,
            created_at: ISO8601DateFormatter().string(from: .now)
        )
        try await client
            .from(Self.communityPosts)
            .insert(row)
            .execute()
    }
}

// MARK: - Lookbook (saved_looks)

/// Ligne upsertée dans la table `saved_looks` lors de la sauvegarde d'un Look du Jour.
struct SupabaseSavedLookRow: Encodable {
    let user_id: String
    let headline: String
    let subline: String
    let style_tag: String
    let weather_emoji: String
    let weather_description: String
    let gender: String
    let catalog_item_ids: [String]
    let wardrobe_item_ids: [String]
    let created_at: String
}

extension SupabaseService {

    /// Sauvegarde un look complet dans la table `saved_looks`.
    /// Fire-and-forget safe — ne throw pas.
    func saveLook(_ look: LookRecommendation) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        let row = SupabaseSavedLookRow(
            user_id:              userId,
            headline:             look.headline,
            subline:              look.subline,
            style_tag:            look.styleTag,
            weather_emoji:        look.weatherEmoji,
            weather_description:  look.weather.weatherEmojiLine,
            gender:               look.gender.rawValue,
            catalog_item_ids:     look.items.map { $0.id.uuidString },
            wardrobe_item_ids:    look.wardrobeItems.map { $0.id.uuidString },
            created_at:           ISO8601DateFormatter().string(from: .now)
        )
        _ = try? await client
            .from(Self.savedLooks)
            .insert(row)
            .execute()
    }
}

// MARK: - Gaming Profile cloud sync

/// Représentation Supabase de la table `gaming_profiles`.
/// Les champs array (earned_badge_ids, completed_quest_ids) sont des colonnes text[].
struct SupabaseGamingProfileRow: Codable {
    let user_id: String
    var total_xp: Int
    var current_level: Int               // StyleLevel.rawValue (1–5)
    var streak: Int
    var longest_streak: Int
    var last_login_date: String          // ISO8601
    var earned_badge_ids: [String]
    var completed_quest_ids: [String]    // UUID strings
    var rank: Int?
    var try_on_count: Int
    var outfit_count: Int
    var share_count: Int
    var challenge_win_count: Int
    var referral_count: Int
    var profile_completed_recorded: Bool
    var updated_at: String               // ISO8601

    var asGamingProfile: GamingProfile {
        let iso = ISO8601DateFormatter()
        var p = GamingProfile()
        p.totalXP                    = total_xp
        p.currentLevel               = StyleLevel(rawValue: current_level) ?? .debutante
        p.streak                     = streak
        p.longestStreak              = longest_streak
        p.lastLoginDate              = iso.date(from: last_login_date) ?? .distantPast
        p.earnedBadgeIDs             = earned_badge_ids
        p.completedQuestIDs          = completed_quest_ids.compactMap { UUID(uuidString: $0) }
        p.rank                       = rank
        p.tryOnCount                 = try_on_count
        p.outfitCount                = outfit_count
        p.shareCount                 = share_count
        p.challengeWinCount          = challenge_win_count
        p.referralCount              = referral_count
        p.profileCompletedRecorded   = profile_completed_recorded
        return p
    }
}

extension SupabaseService {

    /// Récupère le profil gaming depuis Supabase pour l'utilisateur connecté.
    /// Retourne `nil` si non connecté ou si aucun profil n'existe encore.
    func fetchGamingProfile() async throws -> GamingProfile? {
        guard let userId = try? await auth.session.user.id.uuidString else { return nil }
        let rows: [SupabaseGamingProfileRow] = try await client
            .from(Self.gamingProfiles)
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.asGamingProfile
    }

    /// Upsert le profil gaming dans Supabase — fire-and-forget safe (ne throw pas).
    func saveGamingProfile(_ profile: GamingProfile) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        let iso = ISO8601DateFormatter()
        let row = SupabaseGamingProfileRow(
            user_id:                    userId,
            total_xp:                   profile.totalXP,
            current_level:              profile.currentLevel.rawValue,
            streak:                     profile.streak,
            longest_streak:             profile.longestStreak,
            last_login_date:            iso.string(from: profile.lastLoginDate),
            earned_badge_ids:           profile.earnedBadgeIDs,
            completed_quest_ids:        profile.completedQuestIDs.map(\.uuidString),
            rank:                       profile.rank,
            try_on_count:               profile.tryOnCount,
            outfit_count:               profile.outfitCount,
            share_count:                profile.shareCount,
            challenge_win_count:        profile.challengeWinCount,
            referral_count:             profile.referralCount,
            profile_completed_recorded: profile.profileCompletedRecorded,
            updated_at:                 iso.string(from: .now)
        )
        _ = try? await client
            .from(Self.gamingProfiles)
            .upsert(row, onConflict: "user_id")
            .execute()
    }
}

// MARK: - AI Styliste

extension SupabaseService {

    /// Calls the `styliste-chat` Edge Function and returns the assistant's reply.
    func chatWithStyliste(
        history: [StylisteMessage.APIMessage],
        context: String
    ) async throws -> String {
        struct Request: Encodable {
            let messages: [StylisteMessage.APIMessage]
            let context: String
        }
        struct Response: Decodable {
            let reply: String
        }
        let response: Response = try await client.functions.invoke(
            "styliste-chat",
            options: FunctionInvokeOptions(body: Request(messages: history, context: context))
        )
        return response.reply
    }
}
