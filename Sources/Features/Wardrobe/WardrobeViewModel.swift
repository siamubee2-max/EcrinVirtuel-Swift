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
    /// French-language user-facing error message surfaced from failed Supabase calls.
    /// Consumers can bind an .alert or banner to this property.
    var errorMessage: String? = nil

    // MARK: Persistence key
    // Les données d'un compte connecté sont stockées sous une clé scoppée par
    // user id : sans cela, un changement de compte sur le même appareil
    // montrait la garde-robe du compte précédent.
    private let baseStorageKey = "ecrin_wardrobe_items_v2"

    /// Numéro d'époque : incrémenté à CHAQUE mutation locale (ajout, édition,
    /// suppression, favori, changement de compte). Un syncFromCloud suspendu
    /// sur le réseau pendant qu'une mutation survient reprendrait avec un
    /// instantané périmé : l'article supprimé ressusciterait (sans sa photo,
    /// déjà effacée du disque), l'édition serait écrasée. Même idiome que
    /// CreditsManager : capturer le monde avant l'await, le vérifier après.
    private var epoch = 0

    /// Suppressions dont le delete cloud n'a pas encore abouti (hors-ligne,
    /// erreur réseau). Sans cette liste, l'article revenait du cloud au sync
    /// suivant — en zombie définitif, puisque sa photo locale est détruite au
    /// moment du delete. Persistée par scope, rejouée à chaque sync.
    private var pendingDeletions: Set<UUID> = []
    private var pendingDeletionsKey: String { storageKey + "_pending_deletions" }
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
        // MOCK SEAM — under UI tests bypass UserDefaults and cloud sync for determinism
        if AppLaunchEnvironment.isUITesting {
            items = FashionItem.samples
            return
        }
        load()
        if items.isEmpty {
            items = FashionItem.samples
            save()
        }
        Task { await syncFromCloud() }
    }

    // MARK: - CRUD

    func add(_ item: FashionItem) {
        epoch += 1
        items.append(item)
        save()
        Task {
            do { try await supabase.saveWardrobeItem(item) }
            catch { errorMessage = "Synchronisation impossible. Réessayez." }
        }
    }

    func update(_ item: FashionItem) {
        epoch += 1
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        save()
        Task {
            do { try await supabase.saveWardrobeItem(item) }
            catch { errorMessage = "Synchronisation impossible. Réessayez." }
        }
    }

    func delete(_ item: FashionItem) {
        epoch += 1
        items.removeAll { $0.id == item.id }
        // La photo vit dans un fichier : sans ça, supprimer un article laissait
        // son image occuper le conteneur pour toujours.
        WardrobePhotoStore.shared.delete(for: item.id)
        // Enregistrée AVANT le delete cloud : si celui-ci échoue (hors-ligne),
        // le prochain sync la rejouera au lieu de ressusciter l'article.
        pendingDeletions.insert(item.id)
        save()
        Task {
            do {
                try await supabase.deleteWardrobeItem(id: item.id)
                pendingDeletions.remove(item.id)
                save()
            }
            catch { errorMessage = "Suppression non synchronisée. Réessayez." }
        }
    }

    func toggleFavorite(_ item: FashionItem) {
        epoch += 1
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[idx]
        updated.isFavorite.toggle()
        items[idx] = updated
        save()
        Task {
            do { try await supabase.updateWardrobeFavorite(id: updated.id, isFavorite: updated.isFavorite) }
            catch { errorMessage = "Synchronisation impossible. Réessayez." }
        }
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
        epoch += 1
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
        // Un sync suspendu sur le réseau pendant que switchUser change de compte
        // reprendrait avec les articles cloud de l'ANCIEN compte — et save() les
        // écrirait sous la clé du NOUVEAU scope (la garde-robe de A persistée
        // sous la clé anonyme, visible par le prochain utilisateur du poste).
        // L'époque couvre le reste : une mutation locale (suppression, édition)
        // pendant l'await rend l'instantané cloud périmé — on le jette.
        let scopeAtStart = userScope
        let epochAtStart = epoch
        // Rejouer d'abord les suppressions en attente : tant qu'elles n'ont pas
        // abouti côté cloud, l'article reviendrait à chaque fetch.
        for id in pendingDeletions {
            Task {
                try? await supabase.deleteWardrobeItem(id: id)
                pendingDeletions.remove(id)
                save()
            }
        }
        do {
            let fetched = try await supabase.fetchWardrobeItems()
            guard scopeAtStart == userScope, epochAtStart == epoch else { return }
            let cloudItems = fetched.filter { !pendingDeletions.contains($0.id) }
            guard !cloudItems.isEmpty else { return }
            // FUSION par article, pas remplacement. La ligne cloud ne porte que
            // 10 colonnes : tags, matière, prix, lien d'achat, prompt, source y
            // sont reconstruits par défaut. `items = cloudItems + localOnly`
            // remplaçait l'article local riche par ce fantôme appauvri À CHAQUE
            // sync — perte silencieuse et définitive pour tout compte connecté.
            // On garde donc la version locale quand elle existe, et on ne
            // reporte du cloud que ce dont il est réellement l'autorité : le
            // favori (togglable d'un autre appareil) et l'image catalogue si le
            // local n'en a pas. Les photos, elles, vivent dans des fichiers
            // nommés par l'identifiant — rien à recoller.
            let localByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let merged = cloudItems.map { cloud -> FashionItem in
                guard var local = localByID[cloud.id] else { return cloud }
                local.isFavorite = cloud.isFavorite
                if local.imageURL == nil { local.imageURL = cloud.imageURL }
                return local
            }
            let cloudIDs = Set(cloudItems.map(\.id))
            let localOnly = items.filter { !cloudIDs.contains($0.id) }
            items = merged + localOnly
            save()
        } catch {
            // Sync failure is non-fatal — local data stays intact.
            errorMessage = "Synchronisation impossible. Réessayez."
        }
    }

    /// Pousse tous les items locaux vers Supabase (utile après connexion).
    func pushAllToCloud() async {
        for item in items {
            do { try await supabase.saveWardrobeItem(item) }
            catch { errorMessage = "Synchronisation impossible. Réessayez." }
        }
    }

    // MARK: - Local persistence

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let data = try? JSONEncoder().encode(pendingDeletions) {
            UserDefaults.standard.set(data, forKey: pendingDeletionsKey)
        }
    }

    private func load() {
        // AVANT tout décodage : `FashionItem` ne porte plus `userPhotoData`, donc
        // décoder puis sauvegarder effacerait les photos des utilisateurs déjà
        // installés. La migration les sort du JSON et les pose sur le disque.
        WardrobePhotoStore.shared.migrateFromUserDefaults(key: storageKey)
        if let raw = UserDefaults.standard.data(forKey: pendingDeletionsKey),
           let pending = try? JSONDecoder().decode(Set<UUID>.self, from: raw) {
            pendingDeletions = pending
        } else {
            pendingDeletions = []
        }
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FashionItem].self, from: data) else { return }
        items = decoded
    }
}
