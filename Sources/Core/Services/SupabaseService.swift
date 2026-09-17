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

// MARK: - Tables (prod schema — 18 tables as of migration 009)
extension SupabaseService {

    // ── Prod tables (exist in production) ───────────────────────────────────
    static let jewelry               = "jewelry"
    static let users                 = "users"
    static let userQuotas            = "user_quotas"
    static let communityPosts        = "community_posts"
    static let clothingCatalog       = "clothing_catalog"
    static let wardrobeItems         = "wardrobe_items"
    static let monitoringEvents      = "monitoring_events"
    static let tryOnResults          = "try_on_results"      // replaces try_on_sessions
    static let partnershipRequests   = "partnership_requests" // replaces partner_applications
    // Tables recréées sur le projet vffafgzlsmfecqejoytw (migration adaptée) :
    static let giftCards             = "gift_cards"
    static let weddingLooks          = "wedding_looks"
    static let savedLooks            = "saved_looks"
    static let tryOnSessions         = "try_on_sessions"

    // ── ABSENT from prod — do NOT use in Supabase queries ───────────────────
    // body_parts        → BodyModelService falls back to empty / local samples
    // saved_looks       → saveLook is local-only no-op (LookDuJourViewModel flag only)
    // wedding_looks     → WeddingViewModel uses UserDefaults only
    // gaming_profiles   → GamingService uses UserDefaults only; cloud sync disabled
    // partner_brands    → PartnerService uses static sample data only
}

// MARK: - Auth
extension SupabaseService {

    var auth: AuthClient { client.auth }

    /// Vrai si une session Supabase Auth valide existe (requis pour tryon-generate).
    func hasValidSession() async -> Bool {
        (try? await auth.session) != nil
    }

    /// Crée une session anonyme silencieuse (3 essais offerts sans compte).
    /// Le trigger `handle_new_user` crédite 3 essais côté serveur.
    /// Retourne false si la création échoue (hors-ligne, feature désactivée).
    func signInAnonymously() async -> Bool {
        do {
            _ = try await auth.signInAnonymously()
            return true
        } catch {
            return false
        }
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

    /// Résout l'`id` interne de la table `users` (PK) depuis l'`auth_id` de session.
    /// Nécessaire pour toute FK `REFERENCES users(id)` — `auth.uid()` ≠ `users.id`.
    func resolveUsersRowID(authId: String) async throws -> String? {
        struct Row: Decodable { let id: String }
        let rows: [Row] = try await client
            .from(Self.users)
            .select("id")
            .eq("auth_id", value: authId)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
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
    ///
    /// Ordre critique : l'Edge Function `delete-user-account` (service_role)
    /// part EN PREMIER — c'est l'autorité qui supprime le compte auth, et les
    /// FK ON DELETE CASCADE de `users` purgent les tables liées. Le flux est
    /// ainsi tout-ou-rien du point de vue client : si elle échoue, RIEN n'a
    /// été détruit (l'utilisateur reste connecté, données intactes, il peut
    /// réessayer) ; si elle réussit, le compte n'existe plus et le nettoyage
    /// résiduel + la fin de session locale sont best-effort.
    /// L'ancien ordre (6 deletes séquentiels PUIS la fonction PUIS signOut)
    /// laissait, sur une coupure réseau à mi-chemin, un utilisateur
    /// « connecté » dont profil et quotas étaient déjà effacés.
    func deleteAccount() async throws {
        guard let userId = try? await auth.session.user.id.uuidString else { return }


        try await client.functions.invoke(
            "delete-user-account",
            options: FunctionInvokeOptions(body: ["user_id": userId])
        )

        // Best-effort : purge les tables sans cascade FK pendant que le JWT
        // local est encore techniquement valide. Toute erreur ici est sans
        // conséquence utilisateur — le compte auth a déjà disparu.
        _ = try? await client.from(Self.savedLooks).delete().eq("user_id", value: userId).execute()
        _ = try? await client.from(Self.tryOnSessions).delete().eq("user_id", value: userId).execute()
        _ = try? await client.from(Self.communityPosts).delete().eq("user_id", value: userId).execute()
        _ = try? await client.from(Self.wardrobeItems).delete().eq("user_id", value: userId).execute()
        _ = try? await client.from(Self.userQuotas).delete().eq("user_id", value: userId).execute()
        _ = try? await client.from(Self.users).delete().eq("auth_id", value: userId).execute()

        // Fin de session locale garantie — le compte n'existe plus côté serveur.
        try? await auth.signOut()
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

    /// Consomme un lien de parrainage : +3 essais pour la filleule ET la marraine
    /// (RPC `redeem_referral`, SECURITY DEFINER — anti-abus côté serveur).
    /// Retourne le nouveau solde de la filleule.
    func redeemReferral(referrerID: UUID) async throws -> Int {
        struct Params: Encodable { let p_referrer: String }
        let remaining: Int = try await client
            .rpc("redeem_referral", params: Params(p_referrer: referrerID.uuidString))
            .execute()
            .value
        return remaining
    }

    /// Enregistre (ou efface) l'horodatage du consentement IA côté serveur (RGPD).
    /// Best-effort : silencieux si pas de session ou en cas d'échec réseau.
    func setAIConsent(granted: Bool) async {
        guard let userID = try? await auth.session.user.id.uuidString else { return }
        struct ConsentUpdate: Encodable { let ai_consent_at: String? }
        let iso = granted ? ISO8601DateFormatter().string(from: Date()) : nil
        _ = try? await client.from(Self.users)
            .update(ConsentUpdate(ai_consent_at: iso))
            .eq("id", value: userID)
            .execute()
    }

    /// Signale un post à la modération (table `post_reports`, RLS : reporter = auth.uid()).
    /// App Store guideline 1.2 — mécanisme de signalement de contenu UGC.
    func reportPost(postID: UUID, reason: String) async {
        guard let reporterID = try? await auth.session.user.id.uuidString else { return }
        struct ReportRow: Encodable {
            let id: String
            let post_id: String
            let reporter_id: String
            let reason: String
            let status: String
        }
        let row = ReportRow(
            id: UUID().uuidString,
            post_id: postID.uuidString,
            reporter_id: reporterID,
            reason: reason,
            status: "pending"
        )
        _ = try? await client.from("post_reports").insert(row).execute()
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

    /// Aucun produit n'a pu être chargé sur un écran d'achat : l'utilisateur voit
    /// un paywall sans offre réelle. Auparavant invisible — l'erreur était avalée
    /// par un `catch` vide côté PaywallViewModel.
    func recordProductsUnavailable(identifiers: [String]) {
        let message = "RevenueCat n'a retourné aucun produit — demandés: \(identifiers.joined(separator: ", "))"
        Task.detached { await SupabaseService.shared.insertMonitoringEvent(type: "products_unavailable", productId: nil, domain: "Paywall", code: -3, message: message) }
    }

    func recordEntitlementMismatch(productId: String) {
        Task.detached { await SupabaseService.shared.insertMonitoringEvent(type: "entitlement_mismatch", productId: productId, domain: "Paywall", code: -1, message: "Purchase succeeded but premium entitlement not active") }
    }

    /// L'achat Apple a réussi mais l'octroi des crédits a échoué : l'utilisateur a payé
    /// sans rien recevoir. Événement à surveiller en priorité — auparavant l'échec était
    /// avalé par un `try?` côté paywall et n'apparaissait nulle part.
    func recordCreditGrantFailure(_ error: Error?, productId: String, transactionId: String?) {
        let ns = error as NSError?
        let message = "credit-generations KO — txn=\(transactionId ?? "nil") — \(error?.localizedDescription ?? "transactionIdentifier manquant")"
        Task.detached {
            await SupabaseService.shared.insertMonitoringEvent(
                type: "credit_grant_failed",
                productId: productId,
                domain: ns?.domain ?? "Paywall",
                code: ns?.code ?? -2,
                message: message
            )
        }
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
        // Maps to prod table `try_on_results` (try_on_sessions does not exist in prod).
        struct TryOnResultInsert: Encodable {
            let id: String
            let user_id: String
            let type: String
            let item_type: String
            let jewelry_item_id: String
            let result_image_url: String
            let is_favorite: Bool
            let is_public: Bool
            let created_at: String
        }
        let row = TryOnResultInsert(
            id: UUID().uuidString,
            user_id: userId,
            type: "jewelry",
            item_type: "jewelry",
            jewelry_item_id: jewelryId,
            result_image_url: resultImageURL ?? "",
            is_favorite: false,
            is_public: false,
            created_at: ISO8601DateFormatter().string(from: .now)
        )
        try await client
            .from(Self.tryOnResults)
            .insert(row)
            .execute()
    }

    func fetchTryOnHistory(limit: Int = 20) async throws -> [TryOnSession] {
        guard let userId = try? await auth.session.user.id.uuidString else { return [] }
        // Reads from prod table `try_on_results`; maps back to TryOnSession.
        struct TryOnResultRow: Decodable {
            let id: String
            let user_id: String
            let jewelry_item_id: String?
            let result_image_url: String?
            let created_at: String
        }
        let rows: [TryOnResultRow] = try await client
            .from(Self.tryOnResults)
            .select("id,user_id,jewelry_item_id,result_image_url,created_at")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.map {
            TryOnSession(
                id: $0.id,
                jewelryId: $0.jewelry_item_id ?? "",
                userId: $0.user_id,
                resultImageURL: $0.result_image_url,
                createdAt: $0.created_at
            )
        }
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
            // post_likes.user_id references users(id), not auth.uid() — resolve it.
            var likedIDs: Set<String> = []
            if let authId = try? await auth.session.user.id.uuidString,
               let userId = try? await resolveUsersRowID(authId: authId) {
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
        // post_likes.user_id references users(id) (FK + RLS) — passing auth.uid()
        // made every insert fail silently under try?.
        guard let authId = try? await auth.session.user.id.uuidString,
              let userId = try? await resolveUsersRowID(authId: authId) else { return }
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
        // community_posts.user_id references users(id) — same resolution as post_likes.
        // Throw (au lieu d'un return silencieux) : le composeur doit savoir que
        // rien n'a été publié pour ne pas afficher un faux succès.
        guard let authId = try? await auth.session.user.id.uuidString,
              let userId = try? await resolveUsersRowID(authId: authId) else {
            throw URLError(.userAuthenticationRequired)
        }
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

    /// Supprime un post de l'utilisateur courant. La policy RLS
    /// « Users own their posts » garantit côté serveur qu'on ne peut
    /// supprimer que les siens — le eq(id) suffit côté client.
    func deleteCommunityPost(id: UUID) async {
        _ = try? await client
            .from(Self.communityPosts)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Héberge l'image d'un post dans le bucket public `community-posts`
    /// et retourne son URL publique. Le bucket doit exister sur le projet
    /// (Dashboard → Storage → New bucket, public). En cas d'absence ou
    /// d'erreur, l'appelant publie sans image.
    func uploadCommunityImage(_ data: Data) async throws -> String {
        let path = "\(UUID().uuidString).jpg"
        _ = try await client.storage
            .from("community-posts")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        return try client.storage
            .from("community-posts")
            .getPublicURL(path: path)
            .absoluteString
    }
}

// MARK: - Lookbook (saved_looks — absent from prod)

extension SupabaseService {

    /// No-op: `saved_looks` table does not exist in prod (migration 009).
    /// The save flag is managed locally in LookDuJourViewModel only.
    func saveLook(_ look: LookRecommendation) async {
        // Intentionally empty — no cloud sync until table is created in prod.
    }
}

// MARK: - Gaming Profile cloud sync (disabled — gaming_profiles absent from prod)

extension SupabaseService {

    /// No-op: `gaming_profiles` table does not exist in prod (migration 009).
    /// GamingService persists locally via UserDefaults; cloud sync deferred.
    func fetchGamingProfile() async throws -> GamingProfile? {
        return nil
    }

    /// No-op: `gaming_profiles` table does not exist in prod (migration 009).
    func saveGamingProfile(_ profile: GamingProfile) async {
        // Intentionally empty — no cloud sync until table is created in prod.
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

// MARK: - MainActor bridging (Swift 6 strict concurrency)
//
// PostgrestResponse is not Sendable, so `client...execute()` cannot be
// awaited directly from @MainActor view models — the response would cross
// into the main actor. These helpers run the query in this service's
// nonisolated context and only let Sendable values (Void / decoded rows)
// cross back.
extension SupabaseService {

    /// Insert a row and discard the non-Sendable response.
    func insertRow<Row: Encodable & Sendable>(_ row: Row, into table: String) async throws {
        _ = try await client.from(table).insert(row).execute()
    }

    /// Upsert a row and discard the non-Sendable response.
    func upsertRow<Row: Encodable & Sendable>(_ row: Row, into table: String) async throws {
        _ = try await client.from(table).upsert(row).execute()
    }

    /// Call an RPC and decode its rows.
    func rpcRows<Row: Decodable & Sendable, Params: Encodable & Sendable>(
        _ fn: String,
        params: Params
    ) async throws -> [Row] {
        try await client.rpc(fn, params: params).execute().value
    }

    /// Latest wedding look rows for a user (WeddingViewModel).
    func latestWeddingRows<Row: Decodable & Sendable>(userId: String) async throws -> [Row] {
        try await client
            .from(Self.weddingLooks)
            .select("id,name,wedding_date,pieces,bridesmaid_emails,is_finalized,created_at")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
    }
}
