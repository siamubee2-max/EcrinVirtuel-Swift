import CoreImage
import UIKit
import XCTest
@testable import EcrinVirtuel

/// Deux régressions coûteuses sont verrouillées ici.
final class SubjectCutoutTests: XCTestCase {

    /// Un détourage porte un canal alpha ; la référence part en JPEG, format
    /// qui n'en a pas. Sans aplat, la transparence devient NOIRE et le modèle
    /// reçoit un article sur fond noir. On vérifie que le fond ressort BLANC
    /// et opaque.
    func testFlattenedOnWhiteRemplaceLaTransparenceParDuBlanc() throws {
        let size = CGSize(width: 8, height: 8)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        // Image entièrement transparente : le pire cas.
        let transparent = UIGraphicsImageRenderer(size: size, format: format).image { _ in }

        let flattened = SubjectCutout.flattenedOnWhite(transparent)
        let pixel = try XCTUnwrap(firstPixel(of: flattened))

        XCTAssertEqual(pixel.alpha, 255, "le résultat doit être opaque")
        XCTAssertEqual(pixel.red, 255)
        XCTAssertEqual(pixel.green, 255)
        XCTAssertEqual(pixel.blue, 255, "un fond noir signifie que l'aplat a sauté")
    }

    /// La photo prise par l'utilisateur DOIT être exposée comme référence : un
    /// article de garde-robe n'a pas d'`imageURL`, et sans cette donnée le
    /// modèle ne voyait jamais l'article.
    func testArticleDeGardeRobeFournitBienUneReferenceAuModele() async throws {
        let photo = try XCTUnwrap(UIImage(systemName: "circle")?.pngData())
        let item = FashionItem(name: "Collier test", category: .necklace)
        // La photo vit dans un fichier nommé par l'identifiant.
        WardrobePhotoStore.shared.save(photo, for: item.id)
        defer { WardrobePhotoStore.shared.delete(for: item.id) }

        XCTAssertEqual(QuickTryOnItem.wardrobe(item).wardrobePhotoID, item.id)

        // Le vrai contrat : la chaîne complète rend des octets exploitables.
        let prepared = await ImageGenerationService.shared.localReferenceData(for: item.id)
        XCTAssertNotNil(prepared, "l'article ne fournit aucune référence au modèle")
        // `await` sorti de l'assertion : les macros XCTAssert prennent une
        // autoclosure, qui n'accepte pas d'appel asynchrone.
        let aucune = await ImageGenerationService.shared.localReferenceData(for: UUID())
        XCTAssertNil(aucune, "un article sans photo ne doit rien fournir")
    }

    /// L'encodage doit rester TRANSPARENT et rester LÉGER. Un repli silencieux
    /// vers un format sans alpha se verrait en production sous forme de fonds
    /// noirs ; un repli vers PNG multiplierait par cinq le poids du dressing
    /// stocké dans UserDefaults.
    func testEncodageGardeLaTransparenceEtBatLePNG() throws {
        let image = try noisyImageWithTransparentRightHalf()

        let encoded = try XCTUnwrap(SubjectCutout.encoded(image))
        let png = try XCTUnwrap(image.pngData())
        XCTAssertLessThan(encoded.count, png.count, "l'encodage est retombé sur PNG")

        let decoded = try XCTUnwrap(UIImage(data: encoded))
        let corner = try XCTUnwrap(pixel(of: decoded, atUnit: CGPoint(x: 0.9, y: 0.5)))
        XCTAssertLessThan(corner.alpha, 128, "la moitié transparente est devenue opaque")
    }

    // MARK: - Helper

    private func firstPixel(of image: UIImage) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        pixel(of: image, atUnit: CGPoint(x: 0.5, y: 0.5))
    }

    /// Lit un pixel en coordonnées relatives (0…1), sans dépendre de la taille.
    private func pixel(of image: UIImage, atUnit point: CGPoint) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        guard let cgImage = image.cgImage else { return nil }
        var component = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &component,
            width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Décaler l'image pour amener le pixel visé sous la fenêtre 1x1.
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        context.draw(cgImage, in: CGRect(x: -point.x * width, y: -(1 - point.y) * height,
                                         width: width, height: height))
        return (component[0], component[1], component[2], component[3])
    }

    /// Bruit aléatoire à gauche, transparent à droite : le pire cas pour PNG
    /// (sans perte, donc il stocke le bruit tel quel) et un test franc de l'alpha.
    private func noisyImageWithTransparentRightHalf() throws -> UIImage {
        let side: CGFloat = 256
        let noise = try XCTUnwrap(CIFilter(name: "CIRandomGenerator")?.outputImage)
            .cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
        let cgNoise = try XCTUnwrap(CIContext().createCGImage(noise, from: noise.extent))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            context.cgContext.clip(to: CGRect(x: 0, y: 0, width: side / 2, height: side))
            context.cgContext.draw(cgNoise, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}
