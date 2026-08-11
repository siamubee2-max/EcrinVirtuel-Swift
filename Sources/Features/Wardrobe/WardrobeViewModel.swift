import SwiftUI

// MARK: - WardrobeViewModel
// Garde-robe persistée localement (UserDefaults) ET synchronisée avec Supabase.
// Stratégie : UserDefaults = source de vérité locale ; Supabase = sync cloud.
// Si l'utilisateur n'est pas connecté, le mode local fonctionne seul.

@Observable
@MainActor
final class WardrobeViewModel {

    // MARK: State
    var items: [FashionItem] = []
    var selectedGroup: FashionGroup = .jewelry
    var selectedCategory: FashionCategory?
    var searchText: String = ""
    var showOnlyFavorites: Bool = false
    var isSyncing: Bool = false

    // MARK: Persistence key
    // Les données d'un compte connecté sont stockées sous une clé scoppée par
    // user id : sans cela, un changement de compte sur le même appareil
    // montrait la garde-robe du compte précédent.
    private let baseStorageKey = "ecrin_wardrobe_items_v2"
    private var userScope: String?
    private var storageKey: String {
        userScope.map { "\(baseStorageKey)_\($0)" } ?? baseStorageKey
    }
    private let supabase = SupabaseService.shared

    // MARK: Computed
    var filteredItems: [FashionItem] {
        var result = items.filter { $0.category.group == selectedGroup }

        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if showOnlyFavorites {
            result = result.filter { $0.isFavorite }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.brand ?? "").localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        return result.sorted { $0.isFavorite && !$1.isFavorite }
    }

    var groupCount: [FashionGroup: Int] {
        Dictionary(grouping: items, by: { $0.category.group })
            .mapValues { $0.count }
    }

    var totalCount: Int { items.count }

    /// Articles vêtements + chaussures uniquement (pour le Look du Jour / WeatherRecommender).
    var clothingAndShoes: [FashionItem] {
        items.filter { $0.category.group == .clothing || $0.category.group == .shoes }
    }

    /// Bijoux de la garde-robe (pour le slot bijou dans les looks).
    var jewelryItems: [FashionItem] {
        items.filter { $0.category.group == .jewelry }
    }

    // MARK: - Init
    init() {
        load()
        if items.isEmpty {
            items = FashionItem.samples
            save()
        }
        Task { await syncFromCloud() }
    }

    // MARK: - CRUD

    func add(_ item: FashionItem) {
        items.append(item)
        save()
        Task { try? await supabase.saveWardrobeItem(item) }
    }

    func update(_ item: FashionItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        save()
        Task { try? await supabase.saveWardrobeItem(item) }
    }

    func delete(_ item: FashionItem) {
        items.removeAll { $0.id == item.id }
        save()
        Task { try? await supabase.deleteWardrobeItem(id: item.id) }
    }

    func toggleFavorite(_ item: FashionItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[idx]
        updated.isFavorite.toggle()
        items[idx] = updated
        save()
        Task { try? await supabase.updateWardrobeFavorite(id: updated.id, isFavorite: updated.isFavorite) }
    }

    func selectGroup(_ group: FashionGroup) {
        withAnimation(EcrinAnimation.springSnap) {
            selectedGroup = group
            selectedCategory = nil
        }
    }

    func selectCategory(_ category: FashionCategory?) {
        withAnimation(EcrinAnimation.springSnap) {
            selectedCategory = category
        }
    }

    // MARK: - Account scope

    /// Bascule la garde-robe sur le compte donné (`nil` = anonyme) :
    /// persiste l'état du scope courant, charge celui du nouveau scope,
    /// puis resynchronise depuis le cloud pour un compte connecté.
    /// À la première connexion d'un compte sur cet appareil (scope vide),
    /// les items construits en anonyme sont repris pour ne rien perdre —
    /// c'est le comportement historique de la clé unique, mais borné à
    /// cette transition anonyme → compte.
    func switchUser(to userId: String?) {
        guard userId != userScope else {
            if userId != nil { Task { await syncFromCloud() } }
            return
        }
        save() // persiste les items du scope quitté sous son ancienne clé
        let carryOver = userScope == nil ? items : []
        userScope = userId
        items = []
        load()
        if items.isEmpty {
            if userId != nil {
                items = carryOver
            } else {
                items = FashionItem.samples
            }
            save()
        }
        if userId != nil {
            Task { await syncFromCloud() }
        }
    }

    // MARK: - Cloud sync

    /// Récupère la garde-robe depuis Supabase et fusionne avec le local.
    /// Supabase a priorité sur les items partagés (même UUID).
    func syncFromCloud() async {
        isSyncing = true
        defer { isSyncing = false }
        guard let cloudItems = try? await supabase.fetchWardrobeItems(), !cloudItems.isEmpty else { return }
        // Merge : conserver les items locaux sans uuid cloud, puis ajouter les cloud.
        // Les lignes cloud ne portent jamais userPhotoData (volontairement non
        // synchronisé) — recopier la photo locale sur l'item cloud correspondant,
        // sinon chaque sync efface les photos de l'utilisateur.
        let localByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let merged = cloudItems.map { cloudItem in
            var patched = cloudItem
            if patched.userPhotoData == nil {
                patched.userPhotoData = localByID[cloudItem.id]?.userPhotoData
            }
            return patched
        }
        let cloudIDs = Set(cloudItems.map(\.id))
        let localOnly = items.filter { !cloudIDs.contains($0.id) }
        items = merged + localOnly
        save()
    }

    /// Pousse tous les items locaux vers Supabase (utile après connexion).
    func pushAllToCloud() async {
        for item in items {
            try? await supabase.saveWardrobeItem(item)
        }
    }

    // MARK: - Local persistence

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FashionItem].self, from: data) else { return }
        items = decoded
    }
}
