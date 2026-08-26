import Foundation
import OSLog
import Observation
import Supabase

// MARK: - ClothingCatalogService

@MainActor
@Observable
final class ClothingCatalogService {

    static let shared = ClothingCatalogService()

    private(set) var womenItems: [CatalogClothingItem] = []
    private(set) var menItems: [CatalogClothingItem] = []
    private(set) var unisexItems: [CatalogClothingItem] = []
    private(set) var isLoading = false
    private(set) var lastError: ClothingCatalogError?
    private(set) var lastFetchedAt: Date?

    var totalCount: Int { womenItems.count + menItems.count + unisexItems.count }

    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    // MARK: - Fetch All

    func fetchAll(force: Bool = false) async {
        // MOCK SEAM — no network call when running under UI tests
        if AppLaunchEnvironment.isUITesting {
            let samples = CatalogClothingItem.samples
            womenItems  = samples.filter { $0.gender == .femme }
            menItems    = samples.filter { $0.gender == .homme }
            unisexItems = samples.filter { $0.gender == .unisexe }
            lastFetchedAt = .now
            return
        }

        if !force, totalCount > 0, lastFetchedAt != nil { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        // Les 3 genres sont indépendants → chargement EN PARALLÈLE (≈3× plus rapide
        // que la version séquentielle femme→homme→unisexe).
        async let women  = safelyFetch(gender: .femme)
        async let men    = safelyFetch(gender: .homme)
        async let unisex = safelyFetch(gender: .unisexe)
        womenItems  = await women
        menItems    = await men
        unisexItems = await unisex

        if totalCount > 0 {
            lastFetchedAt = .now
        }
    }

    func fetchByGender(_ gender: ClothingGender) async -> [CatalogClothingItem] {
        await safelyFetch(gender: gender)
    }

    func fetchByCategory(_ category: String, gender: ClothingGender? = nil) async -> [CatalogClothingItem] {
        do {
            var query = client
                .from(SupabaseService.clothingCatalog)
                .select()
                .eq("category", value: category)

            if let gender {
                query = query.eq("gender", value: gender.rawValue)
            }

            return try await query
                .order("is_featured", ascending: false)
                .order("name")
                .execute()
                .value
        } catch {
            lastError = .fetchFailed(error.localizedDescription)
            return []
        }
    }

    func fetchFeatured(limit: Int = 10) async -> [CatalogClothingItem] {
        do {
            return try await client
                .from(SupabaseService.clothingCatalog)
                .select()
                .eq("is_featured", value: true)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } catch {
            lastError = .fetchFailed(error.localizedDescription)
            return []
        }
    }

    func search(query: String) async -> [CatalogClothingItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        // MOCK SEAM — use in-memory data when running under UI tests (no network call)
        if AppLaunchEnvironment.isUITesting {
            return searchLocally(query: query)
        }
        let term = query.lowercased()
        do {
            let byName: [CatalogClothingItem] = try await client
                .from(SupabaseService.clothingCatalog)
                .select()
                .ilike("name", pattern: "%\(term)%")
                .order("is_featured", ascending: false)
                .limit(20)
                .execute()
                .value

            let byBrand: [CatalogClothingItem] = try await client
                .from(SupabaseService.clothingCatalog)
                .select()
                .ilike("brand", pattern: "%\(term)%")
                .order("is_featured", ascending: false)
                .limit(10)
                .execute()
                .value

            var seen = Set<UUID>()
            return (byName + byBrand).filter { seen.insert($0.id).inserted }
        } catch {
            lastError = .fetchFailed(error.localizedDescription)
            return searchLocally(query: query)
        }
    }

    func items(for gender: ClothingGender) -> [CatalogClothingItem] {
        switch gender {
        case .femme:   return womenItems
        case .homme:   return menItems
        case .unisexe: return unisexItems
        }
    }

    /// Filtre local sur le cache chargé (genre + saison + catégorie optionnelle).
    func fetchBySeasonAndCategory(
        season: WeatherSeason,
        gender: ClothingGender,
        category: String? = nil
    ) -> [CatalogClothingItem] {
        var list = items(for: gender)
        if gender != .unisexe {
            var seen = Set(list.map(\.id))
            list += unisexItems.filter { seen.insert($0.id).inserted }
        }
        let seasonTags = Set(season.seasonTags)
        list = list.filter { item in
            item.season.isEmpty || !Set(item.season).isDisjoint(with: seasonTags)
        }
        if let category {
            list = list.filter { $0.category == category }
        }
        return list
    }

    // MARK: - Private helpers

    private static let selectColumns =
        "id,name,gender,category,subcategory,brand,color,material,style_tags,season,image_url,try_on_prompt,is_featured,price_eur,purchase_url"

    private func safelyFetch(gender: ClothingGender) async -> [CatalogClothingItem] {
        // 1. SDK Supabase (chemin principal)
        do {
            let items: [CatalogClothingItem] = try await client
                .from(SupabaseService.clothingCatalog)
                .select(Self.selectColumns)
                .eq("gender", value: gender.rawValue)
                .order("category")
                .order("name")
                .execute()
                .value
            if !items.isEmpty { return items }
        } catch {
            Logger(subsystem: "com.ecrin.jewelry", category: "catalog").error("ClothingCatalogService SDK \(gender.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        // 2. Fallback REST direct (contourne les soucis SDK / session)
        do {
            let items = try await fetchViaREST(gender: gender)
            if !items.isEmpty { return items }
        } catch {
            Logger(subsystem: "com.ecrin.jewelry", category: "catalog").error("ClothingCatalogService REST \(gender.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            lastError = .fetchFailed("\(gender.rawValue): \(error.localizedDescription)")
        }

        return []
    }

    /// Fetch via PostgREST REST — même endpoint que le SDK, plus fiable en session Apple Sign-In.
    private func fetchViaREST(gender: ClothingGender) async throws -> [CatalogClothingItem] {
        guard !Secrets.supabaseURL.isEmpty, !Secrets.supabaseAnonKey.isEmpty else {
            throw URLError(.badURL)
        }

        var components = URLComponents(string: "\(Secrets.supabaseURL)/rest/v1/clothing_catalog")!
        components.queryItems = [
            URLQueryItem(name: "gender", value: "eq.\(gender.rawValue)"),
            URLQueryItem(name: "select", value: Self.selectColumns),
            URLQueryItem(name: "order", value: "category.asc,name.asc"),
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = try? await client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(120))"])
        }

        return try JSONDecoder().decode([CatalogClothingItem].self, from: data)
    }

    private func searchLocally(query: String) -> [CatalogClothingItem] {
        let q = query.lowercased()
        let all = womenItems + menItems + unisexItems
        return all.filter {
            $0.name.lowercased().contains(q) ||
            ($0.brand?.lowercased().contains(q) ?? false)
        }
    }
}

enum ClothingCatalogError: LocalizedError {
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let msg): return "Impossible de charger le catalogue : \(msg)"
        }
    }
}
