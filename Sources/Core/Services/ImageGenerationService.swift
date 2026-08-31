import UIKit

// MARK: - Modèle de génération
// Tout passe par le proxy Supabase Edge Function → Google Gemini (primary) → GPT Image fallback.
// La clé API n'est JAMAIS côté iOS — elle vit uniquement dans les secrets Supabase.
//
// Nano Banana 2  (Gemini 3.1 Flash Image) $0.045 — identity preservation ⭐
// Nano Banana Pro(Gemini 3 Pro Image)      $0.134 — outfit complet / export
// Imagen 4 Fast                            $0.020 — previews rapides
// Fallback GPT Image 2.0                   $0.042 — si Google indisponible
enum GenerationModel: String {
    case preview  = "preview"   // Imagen 4 Fast — $0.020
    case standard = "standard"  // Gemini 3.1 Flash Image (NB2) — $0.045 ⭐
    case premium  = "premium"   // Gemini 3 Pro Image (NBPro) — $0.134

    var costUSD: Double {
        switch self {
        case .preview:  return 0.020
        case .standard: return 0.045
        case .premium:  return 0.134
        }
    }
}

/// Format vertical attendu pour essayage rapide et multi-vues (aligné UI 9:16).
enum GenerationAspectRatio {
    static let tryOn = "9:16"
}

/// Catégorie d'essayage → l'Edge Function choisit le « bon générateur » et le bon
/// cadrage : bijoux (gros plan zone) ≠ vêtements (plein corps) ≠ chaussures.
enum GenerationCategory: String {
    case jewelry, clothing, shoes
}

// MARK: - Service (Sendable — toutes propriétés sont let)
final class ImageGenerationService: Sendable {

    static let shared = ImageGenerationService()

    private let proxyURL: URL
    private let session: URLSession

    private init() {
        guard let url = URL(string: "\(Secrets.supabaseURL)/functions/v1/tryon-generate") else {
            fatalError("SUPABASE_URL invalide — proxy tryon-generate")
        }
        proxyURL = url
        let config = URLSessionConfiguration.default
        // L'Edge Function ne renvoie RIEN avant la fin (pas de streaming) : quand le
        // modèle primaire échoue et que la cascade enchaîne les fallbacks, aucun octet
        // n'arrive pendant >60 s. Un timeoutIntervalForRequest à 60 s coupait alors la
        // requête AVANT que le serveur ait fini → « image non générée » à tort.
        // On aligne les deux timeouts sur le budget serveur (cascade plafonnée ~130 s).
        config.timeoutIntervalForRequest  = 180  // pas de coupure prématurée sans octet reçu
        config.timeoutIntervalForResource = 180  // timeout total ressource
        session = URLSession(configuration: config)
    }

    // MARK: - Jewelry try-on

    func tryOn(photo: UIImage, jewelry: JewelryItem) async throws -> UIImage {
        guard let imageData = resizedImageData(photo) else {
            throw GenerationError.invalidImage
        }

        let prompt = """
        EDIT the reference photo of the person: keep the SAME background, lighting, colours and mood — \
        only add \(jewelry.prompt), rendered at realistic true-to-life scale (never oversized). \
        Photorealistic, seamlessly composited. Do NOT beautify, relight, recolour or replace the background. \
        Keep the person's face, skin tone, and pose exactly the same.
        """

        let reference = await downloadReference(jewelry.imageURL)
        return try await sendRequest(imageData: imageData, prompt: prompt, category: .jewelry, referenceImageData: reference)
    }

    // MARK: - QuickTryOn — prompt libre

    func tryOnQuick(
        photo: UIImage,
        prompt: String,
        model: GenerationModel = .standard,
        referenceImageData: Data? = nil
    ) async throws -> UIImage {
        guard let imageData = resizedImageData(photo) else {
            throw GenerationError.invalidImage
        }
        return try await sendRequest(imageData: imageData, prompt: prompt, model: model, referenceImageData: referenceImageData)
    }

    /// Télécharge l'image produit d'un article pour la réutiliser comme référence
    /// (ex MultiPose : 1 seul fetch pour N poses). Retourne nil si indisponible.
    func referenceData(for url: URL?) async -> Data? {
        await downloadReference(url)
    }

    /// Prépare la photo LOCALE d'un article comme image de référence : lecture
    /// du fichier, aplat blanc, compression.
    ///
    /// La LECTURE est à l'intérieur de la tâche détachée, pas avant elle.
    /// `WardrobePhotoStore.data(for:)` est un `Data(contentsOf:)` synchrone, et
    /// l'appelant est tantôt le main actor (MultiPoseViewModel est `@MainActor`),
    /// tantôt un fil du pool coopératif — que Swift 6 interdit de bloquer.
    /// Prendre l'identifiant plutôt que les octets rend cette garantie
    /// impossible à contourner par mégarde.
    func localReferenceData(for id: UUID) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let data = WardrobePhotoStore.shared.data(for: id),
                  let image = UIImage(data: data) else { return nil }
            return self.resizedImageData(SubjectCutout.flattenedOnWhite(image))
        }.value
    }

    // MARK: - QuickTryOn Enrichi — analyse corporelle + prompt contextuel

    // PAS @MainActor : la compression JPEG (resizedImageData) + l'analyse Vision
    // doivent tourner hors du thread UI. BodyContextAnalyzer est @unchecked Sendable
    // et EnrichedPromptBuilder.build est pur — rien n'exige le main actor ici.
    func tryOnEnriched(
        photo: UIImage,
        item: QuickTryOnItem,
        mode: QuickTryOnMode
    ) async throws -> (image: UIImage, context: BodyContext) {
        guard let imageData = resizedImageData(photo) else {
            throw GenerationError.invalidImage
        }

        let bodyContext = await BodyContextAnalyzer.shared.analyze(image: photo)
        let prompt = EnrichedPromptBuilder.build(
            for: item,
            mode: mode,
            bodyContext: bodyContext
        )
        let category: GenerationCategory = switch mode {
        case .jewelsOnly:                 .jewelry
        case .shoesOnly, .shoesAndBottom: .shoes
        default:                          .clothing
        }
        let reference = await downloadReference(item.referenceImageURL)
        let generated = try await sendRequest(imageData: imageData, prompt: prompt, category: category, referenceImageData: reference)
        return (image: generated, context: bodyContext)
    }

    // MARK: - FashionItem try-on (garde-robe étendue)

    func tryOnFashion(
        photo: UIImage,
        item: FashionItem,
        angle: ShootingAngle = .front,
        model: GenerationModel = .standard
    ) async throws -> UIImage {
        guard let imageData = resizedImageData(photo) else {
            throw GenerationError.invalidImage
        }

        let prompt = buildPrompt(for: item, angle: angle)
        let category: GenerationCategory = switch item.category.group {
        case .jewelry: .jewelry
        case .shoes:   .shoes
        default:       .clothing   // .clothing + .accessories
        }
        let reference = await reference(for: item)
        return try await sendRequest(imageData: imageData, prompt: prompt, model: model, category: category, referenceImageData: reference)
    }

    // MARK: - Private helpers

    /// Image de référence d'un article : la photo prise par l'utilisateur passe
    /// AVANT le catalogue.
    ///
    /// Un article ajouté à la garde-robe n'a pas d'`imageURL` — sa photo vit
    /// dans un fichier. Elle ne servait donc qu'à la vignette : le modèle
    /// ne voyait jamais l'article et réinventait un bijou générique à partir du
    /// seul texte du prompt. Détourer sans corriger ça n'aurait rien changé au
    /// rendu.
    private func reference(for item: FashionItem) async -> Data? {
        if let local = await localReferenceData(for: item.id) {
            return local
        }
        return await downloadReference(item.imageURL)
    }

    /// Télécharge l'image produit du catalogue (vraie photo de l'article) pour
    /// la fournir au modèle comme référence — garantit le bon bijou / vêtement.
    /// Retourne nil si pas d'URL ou échec → fallback prompt-texte (comportement historique).
    private func downloadReference(_ url: URL?) async -> Data? {
        guard let url else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let image = UIImage(data: data) else { return nil }
            return resizedImageData(image)
        } catch {
            return nil
        }
    }

    /// Redimensionne (max 2048 px côté long) puis compresse l'image pour
    /// rester sous `maxBytes`. La baisse de qualité seule ne suffisait pas :
    /// photo + référence partent en base64 (+33 %) dans le MÊME payload JSON,
    /// et une photo 48 MP pouvait dépasser la limite de l'Edge Function
    /// (413 rendu comme apiError générique).
    private func resizedImageData(_ image: UIImage, maxBytes: Int = 4 * 1024 * 1024) -> Data? {
        let scaled = downscaled(image, maxDimension: 2048)
        var quality: CGFloat = 0.85
        while quality > 0.1 {
            if let data = scaled.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.15
        }
        return scaled.jpegData(compressionQuality: 0.1)
    }

    private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func buildPrompt(for item: FashionItem, angle: ShootingAngle) -> String {
        let angleTag: String = switch angle {
        case .front: "Front-facing view."
        case .side:  "Side profile view."
        case .down:  "Top-down view of feet."
        }

        let parts: [String?] = [
            item.tryOnPrompt,
            item.material.map { "Material: \($0)." },
            item.color.map { "Color: \($0)." },
            item.brand.map { "Brand style: \($0)." },
            angleTag,
            "EDIT the reference photo: keep the same background, lighting and colours — only add the item. Photorealistic, seamlessly composited. Do NOT beautify, relight, recolour or replace the background. Keep the person's face, skin tone, and body proportions exactly the same."
        ]
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Envoie la requête en JSON (base64) vers le proxy Supabase.
    /// L'Edge Function retourne { result: string_base64, provider: string }.
    private func sendRequest(
        imageData: Data,
        prompt: String,
        model: GenerationModel = .standard,
        category: GenerationCategory? = nil,
        referenceImageData: Data? = nil
    ) async throws -> UIImage {
        // Apple 5.1.1(i) / 5.1.2(i) — le consentement est demandé ICI, au seul point
        // de passage de tous les écrans d'essayage : aucune photo ne peut partir sans
        // accord explicite, et un futur appelant ne peut pas court-circuiter la porte.
        guard await AIConsentGate.requireConsent() else {
            throw GenerationError.consentDeclined
        }

        // Obtenir le JWT utilisateur.
        // Pour les utilisateurs non connectés (wizard first-run), on crée une session anonyme.
        // L'Edge Function accepte les users anonymes Supabase (isAnonymous = true côté serveur).
        let userJWT: String
        do {
            userJWT = try await SupabaseService.shared.client.auth.session.accessToken
        } catch {
            // Pas de session — créer une session anonyme (premier essai sans compte)
            do {
                let anon = try await SupabaseService.shared.client.auth.signInAnonymously()
                userJWT = anon.accessToken
            } catch {
                throw GenerationError.authenticationRequired
            }
        }

        var body: [String: Any] = [
            "imageBase64": imageData.base64EncodedString(),
            "prompt": prompt,
            "model": model.rawValue,
            "quality": "medium",
            "aspectRatio": GenerationAspectRatio.tryOn,
        ]
        if let category {
            body["category"] = category.rawValue
        }
        if let referenceImageData {
            body["referenceImageBase64"] = referenceImageData.base64EncodedString()
        }

        // M4 — App Attest: attach attestation/assertion headers best-effort.
        // With APP_ATTEST_MODE=off (server default) these are silently ignored.
        // Skipped on Simulator, -uitest, and unsupported devices.
        let clientDataHash = AttestationService.clientDataHash(from: body)
        let attestHeaders = await AttestationService.shared.attestationHeaders(clientDataHash: clientDataHash)

        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(userJWT)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in attestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GenerationError.apiError
        }

        if http.statusCode == 401 {
            throw GenerationError.authenticationRequired
        }

        guard http.statusCode == 200 else {
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = body["error"] as? String {
                if msg == "unauthorized" {
                    throw GenerationError.authenticationRequired
                }
                if msg == "quota_exceeded" {
                    throw GenerationError.quotaExceeded
                }
                throw GenerationError.serverError(msg)
            }
            throw GenerationError.apiError
        }

        let decoded = try JSONDecoder().decode(EdgeResponse.self, from: data)
        guard let imgData = Data(base64Encoded: decoded.result),
              let image = UIImage(data: imgData) else {
            throw GenerationError.invalidResponse
        }
        return image
    }

    enum GenerationError: Error, LocalizedError {
        case invalidImage
        case apiError
        case invalidResponse
        case authenticationRequired
        case consentDeclined
        case quotaExceeded
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage:              return "Impossible de lire l'image sélectionnée."
            case .apiError:                  return "Erreur lors de la génération. Réessayez."
            case .invalidResponse:           return "Réponse inattendue du serveur."
            case .authenticationRequired:    return "Connectez-vous avec Apple pour générer votre essayage."
            case .consentDeclined:           return L10n.TryOnUI.consentDeclinedMessage
            case .quotaExceeded:             return "Plus de crédits disponibles. Passez à un abonnement pour continuer."
            case .serverError(let msg):      return "Serveur : \(msg)"
            }
        }
    }
}

// MARK: - Response model (format retourné par tryon-generate Edge Function)
private struct EdgeResponse: Decodable {
    let result: String
    let provider: String
}
