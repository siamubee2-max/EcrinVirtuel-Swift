import UIKit
import XCTest
@testable import EcrinVirtuel

/// Le passage des photos de `UserDefaults` vers des fichiers touche les données
/// d'utilisateurs déjà installés. Ces tests couvrent le chemin où une erreur ne
/// se rattrape pas : la migration.
final class WardrobePhotoStoreTests: XCTestCase {

    private var directory: URL!
    private var store: WardrobePhotoStore!
    private var defaults: UserDefaults!
    private let suiteName = "ecrin.tests.wardrobephotostore"

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WardrobePhotoStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = WardrobePhotoStore(directory: directory)
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try super.tearDownWithError()
    }

    // MARK: - Aller-retour

    func testUnePhotoEcriteSeRelitPuisDisparaitApresSuppression() throws {
        let id = UUID()
        let photo = try photoBytes()

        XCTAssertNil(store.data(for: id))
        XCTAssertFalse(store.hasPhoto(for: id))

        XCTAssertTrue(store.save(photo, for: id))
        XCTAssertEqual(store.data(for: id), photo)
        XCTAssertTrue(store.hasPhoto(for: id))
        XCTAssertNotNil(store.image(for: id))

        store.delete(for: id)
        XCTAssertNil(store.data(for: id))
        XCTAssertNil(store.image(for: id), "le cache mémoire doit être vidé avec le fichier")
    }

    /// Le cache ne doit pas servir une image périmée après réécriture.
    func testLeCacheSuitLaReecriture() throws {
        let id = UUID()
        store.save(try photoBytes(color: .red, side: 12), for: id)
        let first = try XCTUnwrap(store.image(for: id))
        XCTAssertEqual(first.size.width, 12)

        store.save(try photoBytes(color: .blue, side: 30), for: id)
        let second = try XCTUnwrap(store.image(for: id))
        XCTAssertEqual(second.size.width, 30, "le cache a resservi l'ancienne image")
    }

    // MARK: - Migration

    func testLaMigrationSortLesPhotosDuJSONSansPerdreLesArticles() throws {
        let item = FashionItem(name: "Collier ancien", category: .necklace, brand: "MONI")
        let photo = try photoBytes()
        let key = "wardrobe_legacy"
        defaults.set(try legacyBlob(items: [item], photos: [item.id: photo]), forKey: key)

        store.migrateFromUserDefaults(key: key, defaults: defaults)

        XCTAssertEqual(store.data(for: item.id), photo, "la photo n'a pas été posée sur le disque")

        let blob = try XCTUnwrap(defaults.data(forKey: key))
        XCTAssertFalse(
            String(decoding: blob, as: UTF8.self).contains("userPhotoData"),
            "le JSON allégé porte encore la photo"
        )

        let survivors = try JSONDecoder().decode([FashionItem].self, from: blob)
        XCTAssertEqual(survivors.map(\.id), [item.id])
        XCTAssertEqual(survivors.first?.name, "Collier ancien")
        XCTAssertEqual(survivors.first?.brand, "MONI")
    }

    /// Rejouée, la migration ne doit pas écraser une photo plus récente par
    /// celle restée dans un JSON périmé.
    func testLaMigrationNecraseJamaisUnePhotoDejaSurDisque() throws {
        let item = FashionItem(name: "Bague", category: .ring)
        let ancienne = try photoBytes(color: .red, side: 12)
        let recente  = try photoBytes(color: .blue, side: 30)
        let key = "wardrobe_legacy_rejoue"
        defaults.set(try legacyBlob(items: [item], photos: [item.id: ancienne]), forKey: key)

        store.save(recente, for: item.id)
        store.migrateFromUserDefaults(key: key, defaults: defaults)

        XCTAssertEqual(store.data(for: item.id), recente)
    }

    /// LE test qui manquait : écriture impossible, le JSON doit garder ses
    /// photos pour un nouvel essai. Sans le garde-fou, elles disparaissaient des
    /// deux côtés et plus rien ne permettait de les reprendre.
    func testUneEcritureImpossibleLaisseLeJSONIntact() throws {
        // Un FICHIER là où le magasin attend un dossier : toute écriture échoue.
        let bloque = FileManager.default.temporaryDirectory
            .appendingPathComponent("bloque-\(UUID().uuidString)", isDirectory: false)
        try Data("pas un dossier".utf8).write(to: bloque)
        defer { try? FileManager.default.removeItem(at: bloque) }
        let bloquant = WardrobePhotoStore(directory: bloque)

        let item = FashionItem(name: "Collier", category: .necklace)
        let key = "wardrobe_disque_plein"
        let legacy = try legacyBlob(items: [item], photos: [item.id: try photoBytes()])
        defaults.set(legacy, forKey: key)

        bloquant.migrateFromUserDefaults(key: key, defaults: defaults)

        XCTAssertFalse(bloquant.hasPhoto(for: item.id))
        XCTAssertEqual(
            defaults.data(forKey: key), legacy,
            "le JSON a été allégé alors que la photo n'a pas pu être écrite"
        )
    }

    func testUnJSONDejaMigreEstLaisseIntact() throws {
        let item = FashionItem(name: "Sans photo", category: .top)
        let key = "wardrobe_deja_migre"
        let clean = try JSONEncoder().encode([item])
        defaults.set(clean, forKey: key)

        store.migrateFromUserDefaults(key: key, defaults: defaults)

        XCTAssertEqual(defaults.data(forKey: key), clean)
        XCTAssertFalse(store.hasPhoto(for: item.id))
    }

    // MARK: - Helpers

    /// Reconstruit l'ANCIEN format : le JSON du modèle actuel, augmenté de la
    /// clé `userPhotoData` que `FashionItem` ne porte plus.
    private func legacyBlob(items: [FashionItem], photos: [UUID: Data]) throws -> Data {
        let encoded = try JSONEncoder().encode(items)
        var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        for index in rows.indices {
            guard let raw = rows[index]["id"] as? String,
                  let id = UUID(uuidString: raw),
                  let photo = photos[id] else { continue }
            rows[index]["userPhotoData"] = photo.base64EncodedString()
        }
        return try JSONSerialization.data(withJSONObject: rows)
    }

    private func photoBytes(color: UIColor = .green, side: CGFloat = 8) throws -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        return try XCTUnwrap(image.pngData())
    }
}
