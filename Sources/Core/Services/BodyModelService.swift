import Foundation
import SwiftUI
import Supabase

// MARK: - BodyModelService
// Charge les mannequins de référence.
// NOTE: `body_parts` table absent from prod (migration 009) — fetchAll is a no-op;
// callers receive an empty list (no models available until table is created).

@MainActor
final class BodyModelService: ObservableObject {

    static let shared = BodyModelService()

    @Published private(set) var globalModels: [BodyModel] = []
    @Published private(set) var userModels:   [BodyModel] = []
    @Published private(set) var isLoading = false
    @Published var error: String?

    private var client: SupabaseClient { SupabaseService.shared.client }
    private init() {}

    // MARK: - Fetch

    /// No-op: `body_parts` table does not exist in prod (migration 009).
    /// Returns empty model lists; feature is deferred until table is added to prod.
    func fetchAll() async {
        globalModels = []
        userModels   = []
    }

    /// Retourne les mannequins compatibles avec un type de bijou donné.
    func models(for jewelryType: String) -> [BodyModel] {
        let matching = globalModels.filter { $0.type.lowercased() == jewelryType.lowercased() }
        return matching.isEmpty ? globalModels : matching
    }

    // MARK: - Image download

    /// Télécharge l'image d'un mannequin et la convertit en UIImage.
    /// Ajoute les headers Supabase (apikey + Authorization) pour les buckets privés.
    func downloadImage(for model: BodyModel) async -> UIImage? {
        guard let url = model.imageURL else { return nil }

        var request = URLRequest(url: url)
        // Headers Supabase — nécessaires pour les buckets Storage non-public
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = try? await SupabaseService.shared.client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            // Vérification HTTP pour détecter les 401/403 silencieux
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
