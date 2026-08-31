import OSLog
import UIKit

// MARK: - WardrobePhotoStore

/// Photos des articles de la garde-robe, stockées en FICHIERS.
///
/// Elles vivaient dans `UserDefaults`, encodées en base64 (+33 %) à l'intérieur
/// du JSON de la garde-robe. `UserDefaults` est un fichier de préférences relu
/// ENTIÈREMENT au lancement de l'app : y mettre des images fait payer à chaque
/// démarrage le poids de tout le dressing, qu'on l'ouvre ou non.
///
/// Ici chaque photo est un fichier nommé par l'identifiant de l'article. Le
/// modèle ne porte plus que cet identifiant, qu'il possédait déjà.
///
/// Deux effets de bord bienvenus :
/// - un article venu du cloud retrouve sa photo tout seul (même `id`), ce qui
///   supprime le recollage manuel que faisait `syncFromCloud` ;
/// - le JSON de la garde-robe redevient minuscule.
///
/// `@unchecked Sendable` : les deux membres sont des `let`, `NSCache` est
/// documenté thread-safe, et les lectures/écritures `FileManager` le sont aussi.
/// Seule l'absence d'annotation `Sendable` sur `NSCache` impose l'échappatoire.
final class WardrobePhotoStore: @unchecked Sendable {

    static let shared = WardrobePhotoStore()

    /// Images décodées, pour ne pas relire le disque à chaque passage de
    /// `body` SwiftUI. Bornée : une garde-robe peut être longue.
    private let cache = NSCache<NSUUID, UIImage>()
    private let directory: URL
    private let log = Logger(subsystem: "com.ecrin.jewelry", category: "wardrobe-photos")

    init(directory: URL? = nil) {
        // Application Support, pas Caches : le système peut vider Caches quand
        // l'espace manque, et ces photos sont irremplaçables. Pas Documents non
        // plus : elles ne sont pas destinées à être vues par l'utilisateur dans
        // l'app Fichiers. Application Support est sauvegardé par iCloud, ce qui
        // est le comportement voulu pour la garde-robe de quelqu'un.
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WardrobePhotos", isDirectory: true)
        cache.countLimit = 60
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: - Lecture

    /// Octets bruts de la photo. Lecture disque : à réserver aux usages ponctuels
    /// (préparation d'une image de référence). Pour AFFICHER, utiliser `image(for:)`,
    /// qui garde le résultat décodé en mémoire.
    func data(for id: UUID) -> Data? {
        try? Data(contentsOf: url(for: id))
    }

    /// Image prête à afficher, décodée une seule fois.
    ///
    /// ponytail: lecture disque synchrone, appelée depuis un `body` SwiftUI au
    /// premier affichage de chaque article. Quelques centaines de kilo-octets
    /// depuis le flash, une fois par article grâce au cache — à comparer à
    /// l'ancien coût, qui relisait TOUTE la garde-robe à chaque lancement.
    /// Si un jour une grande garde-robe fait sauter le défilement, passer à un
    /// chargement asynchrone avec image de remplacement.
    func image(for id: UUID) -> UIImage? {
        if let cached = cache.object(forKey: id as NSUUID) { return cached }
        guard let data = data(for: id), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: id as NSUUID)
        return image
    }

    func hasPhoto(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    // MARK: - Écriture

    @discardableResult
    func save(_ data: Data, for id: UUID) -> Bool {
        do {
            // Le dossier peut manquer : sa création à l'init avale son échec, et
            // rien ne garantit qu'il survit à une restauration de sauvegarde.
            // Le recréer ici coûte un appel et supprime la cause la plus
            // probable d'un échec d'écriture.
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Atomique : une écriture interrompue ne doit pas laisser un fichier
            // à moitié écrit, qui se lirait comme une image corrompue.
            try data.write(to: url(for: id), options: .atomic)
            cache.removeObject(forKey: id as NSUUID)
            return true
        } catch {
            // Ne pas avaler : sans photo écrite, l'article s'affichera avec un
            // simple pictogramme et partira en génération sans référence — un
            // symptôme muet qu'on ne pourrait pas expliquer autrement.
            log.error("écriture de la photo \(id, privacy: .public) impossible : \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
        cache.removeObject(forKey: id as NSUUID)
    }

    // MARK: - Migration

    /// Extrait les photos encore embarquées dans le JSON `UserDefaults` d'une
    /// clé de garde-robe, les écrit sur disque, puis réécrit le JSON sans elles.
    ///
    /// DOIT tourner AVANT le premier décodage de `[FashionItem]` : le modèle ne
    /// porte plus `userPhotoData`, donc un décodage normal ignorerait la clé et
    /// la sauvegarde suivante effacerait définitivement les photos existantes.
    ///
    /// Idempotente : une photo déjà présente sur disque n'est pas réécrite, et
    /// un JSON déjà nettoyé ne contient plus rien à extraire.
    ///
    /// ponytail: synchrone, sur le main actor, au lancement. Volontaire —
    /// l'ordre « migrer avant de décoder » est une garantie sur les données de
    /// l'utilisateur, pas une optimisation qu'on peut rendre asynchrone. Le coût
    /// n'est payé qu'AU SEUL lancement qui migre, et il vaut deux décodages du
    /// gros JSON — celui que l'ancienne version relisait à CHAQUE lancement.
    /// Ensuite le JSON est minuscule et le premier `guard` sort immédiatement.
    func migrateFromUserDefaults(key: String, defaults: UserDefaults = .standard) {
        guard let blob = defaults.data(forKey: key),
              let legacy = try? JSONDecoder().decode([LegacyPhotoRow].self, from: blob)
        else { return }

        let carriers = legacy.filter { $0.userPhotoData != nil }
        guard !carriers.isEmpty else { return }

        // `map` et non `allSatisfy` : pas de court-circuit, on tente TOUTES les
        // photos même si l'une échoue.
        let written = carriers.map { row -> Bool in
            guard let data = row.userPhotoData else { return true }
            // Ne jamais écraser une photo déjà sur disque : elle est forcément
            // plus récente que celle restée dans le JSON.
            if hasPhoto(for: row.id) { return true }
            return save(data, for: row.id)
        }

        // UNE seule écriture ratée (disque plein, dossier inaccessible) et on
        // laisse le JSON intact. L'alléger quand même effacerait les photos DES
        // DEUX CÔTÉS : plus rien sur le disque, et plus rien à reprendre au
        // lancement suivant puisque `carriers` serait vide. Perte définitive.
        guard written.allSatisfy({ $0 }) else {
            log.error("migration incomplète pour \(key, privacy: .public) : JSON laissé intact pour un nouvel essai")
            return
        }

        // Réécrire le JSON allégé tout de suite. Attendre la prochaine
        // sauvegarde laisserait le poids dans UserDefaults tant que
        // l'utilisateur ne touche pas à sa garde-robe.
        if let items = try? JSONDecoder().decode([FashionItem].self, from: blob),
           let slimmed = try? JSONEncoder().encode(items) {
            defaults.set(slimmed, forKey: key)
        }
    }

    /// Vue minimale de l'ancien format : seuls l'identifiant et la photo
    /// comptent, `JSONDecoder` ignore le reste des colonnes.
    private struct LegacyPhotoRow: Decodable {
        let id: UUID
        let userPhotoData: Data?
    }

    // MARK: - Private

    /// Pas d'extension de fichier : selon le réglage de détourage la photo est
    /// du HEIC ou l'original de la pellicule. `UIImage` reconnaît le format à
    /// partir des octets, l'extension n'apporterait qu'une occasion de mentir.
    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString, isDirectory: false)
    }
}
