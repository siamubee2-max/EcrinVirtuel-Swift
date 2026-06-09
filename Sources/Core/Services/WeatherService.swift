import CoreLocation
import Foundation
import Observation

// MARK: - WeatherService

@Observable
@MainActor
final class WeatherService {

    static let shared = WeatherService()

    private(set) var snapshot: WeatherSnapshot?
    private(set) var isLoading = false
    private(set) var lastError: WeatherError?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Cache

    func loadFromCache() -> WeatherSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: WeatherPersistence.snapshotCacheKey),
              let cached = try? decoder.decode(WeatherSnapshot.self, from: data) else {
            return nil
        }
        snapshot = cached
        return cached
    }

    func isCacheValid(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard let cached = snapshot ?? loadFromCache() else { return false }
        let age = Date().timeIntervalSince(cached.fetchedAt)
        if age > WeatherPersistence.cacheDuration { return false }
        if cached.distanceKm(to: coordinate.latitude, otherLon: coordinate.longitude) > WeatherPersistence.significantMoveKm {
            return false
        }
        return true
    }

    // MARK: - Fetch

    func fetchCurrent(coordinate: CLLocationCoordinate2D, cityName: String?, force: Bool = false) async {
        if !force, isCacheValid(for: coordinate) {
            return
        }
        await performFetch(coordinate: coordinate, cityName: cityName)
    }

    func refresh(coordinate: CLLocationCoordinate2D, cityName: String?) async {
        await performFetch(coordinate: coordinate, cityName: cityName)
    }

    private func performFetch(coordinate: CLLocationCoordinate2D, cityName: String?) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,precipitation,windspeed_10m,weathercode,uv_index"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        guard let url = components.url else {
            lastError = .invalidURL
            return
        }

        do {
            let (data, response) = try await fetchWithRetry(url: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                lastError = .serverError
                return
            }

            let api = try decoder.decode(OpenMeteoForecastResponse.self, from: data)
            let built = WeatherSnapshot(
                latitude: api.latitude,
                longitude: api.longitude,
                cityName: cityName,
                fetchedAt: .now,
                temperatureC: api.current.temperature2m,
                feelsLikeC: api.current.apparentTemperature,
                precipitationMM: api.current.precipitation,
                windspeedKmh: api.current.windspeed10m,
                uvIndex: api.current.uvIndex,
                weatherCode: api.current.weathercode
            )
            snapshot = built
            persistSnapshot(built)
        } catch {
            lastError = .network(error.localizedDescription)
            if snapshot == nil {
                _ = loadFromCache()
            }
        }
    }

    private func fetchWithRetry(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        do {
            return try await session.data(for: request)
        } catch {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            return try await session.data(for: request)
        }
    }

    private func persistSnapshot(_ snapshot: WeatherSnapshot) {
        if let data = try? encoder.encode(snapshot) {
            UserDefaults.standard.set(data, forKey: WeatherPersistence.snapshotCacheKey)
        }
    }
}

// MARK: - Erreurs

enum WeatherError: LocalizedError, Equatable {
    case invalidURL
    case serverError
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL météo invalide."
        case .serverError:
            return "Le service météo est indisponible."
        case .network(let message):
            return "Connexion météo impossible : \(message)"
        }
    }
}

// MARK: - Open-Meteo DTO

private struct OpenMeteoForecastResponse: Decodable, Sendable {
    let latitude: Double
    let longitude: Double
    let current: OpenMeteoCurrent
}

private struct OpenMeteoCurrent: Decodable, Sendable {
    let temperature2m: Double
    let apparentTemperature: Double
    let precipitation: Double
    let windspeed10m: Double
    let weathercode: Int
    let uvIndex: Double

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitation
        case windspeed10m = "windspeed_10m"
        case weathercode
        case uvIndex = "uv_index"
    }
}
