import ImageIO
import UIKit
import UniformTypeIdentifiers
import Vision

// MARK: - SubjectCutout

/// Détourage du sujet principal d'une photo, entièrement sur l'appareil.
///
/// Une photo d'article prise par un utilisateur ou un vendeur montre rarement
/// l'article seul : il y a le cintre, la table, le chevalet, la carte de visite
/// de la boutique. Ce décor partait tel quel dans l'image de référence envoyée
/// au modèle, qui le reproduisait ou s'en servait pour estimer l'échelle.
///
/// Vision fait ici exactement le « lift » de l'appui long dans Photos :
/// gratuit, hors ligne, environ 200 ms. Inutile d'appeler un service de
/// segmentation facturé à l'image pour un besoin que le système couvre.
enum SubjectCutout {

    /// Retourne le sujet sur fond transparent, recadré au plus juste.
    ///
    /// `nil` quand Vision ne distingue aucun sujet (photo trop uniforme, article
    /// à plat sur un fond de même couleur). L'appelant garde alors la photo
    /// d'origine : mieux vaut le décor qu'une image vide.
    static func lift(_ image: UIImage, maxDimension: CGFloat = 1536) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            // Redimensionner AVANT Vision : une photo 48 MP coûte des secondes
            // pour un masque qui n'en sera pas meilleur. Le redessin fixe aussi
            // l'orientation dans les pixels — plus de table de correspondance
            // UIImage.Orientation → CGImagePropertyOrientation à tenir juste.
            let normalized = normalizedForVision(image, maxDimension: maxDimension)
            guard let cgImage = normalized.cgImage else { return nil }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            let request = VNGenerateForegroundInstanceMaskRequest()

            guard (try? handler.perform([request])) != nil,
                  let result = request.results?.first,
                  !result.allInstances.isEmpty,
                  let masked = try? result.generateMaskedImage(
                      ofInstances: result.allInstances,
                      from: handler,
                      croppedToInstancesExtent: true
                  )
            else { return nil }

            let ciImage = CIImage(cvPixelBuffer: masked)
            guard let cutout = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: cutout)
        }.value
    }

    /// Encode un détourage en conservant la transparence, sans le poids du PNG.
    ///
    /// PNG est SANS PERTE : il stocke chaque pixel photographique tel quel. Sur
    /// un détourage de basket il pèse 660 Ko contre 128 Ko pour la photo
    /// d'origine, et 8 Mo sur un bijou en 12 Mpx. Cette donnée part dans
    /// `UserDefaults` en base64 (+33 %), chargé en mémoire à chaque lancement.
    ///
    /// HEIC compresse comme JPEG ET garde le canal alpha : 109 Ko sur la même
    /// basket, soit six fois moins. Repli sur PNG si l'encodage échoue — mieux
    /// vaut lourd que sans transparence, un alpha perdu devient du noir.
    static func encoded(_ image: UIImage, quality: CGFloat = 0.8) -> Data? {
        guard let cgImage = image.cgImage else { return image.pngData() }
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            buffer, UTType.heic.identifier as CFString, 1, nil
        ) else { return image.pngData() }

        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination), buffer.length > 0 else {
            return image.pngData()
        }
        return buffer as Data
    }

    /// Pose l'image sur un fond blanc opaque.
    ///
    /// Un détourage porte un canal alpha, or les images de référence partent en
    /// JPEG vers l'Edge Function : sans fond posé, la transparence devient NOIRE
    /// et le modèle reçoit un article sur fond noir. Blanc = photo produit,
    /// exactement la convention que le prompt lui demande de reconnaître.
    static func flattenedOnWhite(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let size = image.size
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Private

    private static func normalizedForVision(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return image }
        let ratio = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
