import CoreLocation
import Foundation
import Observation

// MARK: - LocationService

@Observable
@MainActor
final class LocationService: NSObject {

    static let shared = LocationService()

    enum LocationSource: Equatable, Sendable {
        case gps
        case manual(String)
        case ip
        case `default`

        var persistenceValue: WeatherLocationSource {
            switch self {
            case .gps: return .gps
            case .manual: return .manual
            case .ip: return .ip
            case .default: return .default
            }
        }
    }

    enum AuthStatus: Sendable {
        case notDetermined
        case denied
        case restricted
        case authorized
    }

    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var cityName: String?
    private(set) var source: LocationSource = .default
    private(set) var authStatus: AuthStatus = .notDetermined
    private(set) var isLocating = false
    private(set) var lastError: String?

    var usesDefaultLocation: Bool {
        if case .default = source { return true }
        return false
    }

    var defaultLocationBadge: String? {
        usesDefaultLocation ? "📍 Paris par défaut — modifiez dans Profil" : nil
    }

    private let locationManager = CLLocationManager()
    private var permissionContinuation: CheckedContinuation<Void, Never>?
    private var locateContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    // MARK: - Persistance

    func loadPersisted() {
        let defaults = UserDefaults.standard

        if let city = defaults.string(forKey: WeatherPersistence.userCityKey), !city.isEmpty {
            cityName = city
        }

        if defaults.object(forKey: WeatherPersistence.lastLatitudeKey) != nil,
           defaults.object(forKey: WeatherPersistence.lastLongitudeKey) != nil {
            let lat = defaults.double(forKey: WeatherPersistence.lastLatitudeKey)
            let lon = defaults.double(forKey: WeatherPersistence.lastLongitudeKey)
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        if let raw = defaults.string(forKey: WeatherPersistence.locationSourceKey),
           let persisted = WeatherLocationSource(rawValue: raw) {
            switch persisted {
            case .gps:
                source = .gps
            case .manual:
                source = .manual(cityName ?? WeatherPersistence.defaultCityName)
            case .ip:
                source = .ip
            case .default:
                source = .default
            }
        }

        if defaults.bool(forKey: WeatherPersistence.locationDeniedKey) {
            authStatus = .denied
        } else {
            refreshAuthStatusFromSystem()
        }

        if coordinate == nil {
            applyDefault()
        }
    }

    private func persistLocation() {
        let defaults = UserDefaults.standard
        if let coordinate {
            defaults.set(coordinate.latitude, forKey: WeatherPersistence.lastLatitudeKey)
            defaults.set(coordinate.longitude, forKey: WeatherPersistence.lastLongitudeKey)
        }
        if let cityName {
            defaults.set(cityName, forKey: WeatherPersistence.userCityKey)
        }
        defaults.set(source.persistenceValue.rawValue, forKey: WeatherPersistence.locationSourceKey)
    }

    // MARK: - API publique

    func requestPermissionAndLocate() async {
        isLocating = true
        lastError = nil
        defer { isLocating = false }

        refreshAuthStatusFromSystem()

        switch authStatus {
        case .notDetermined:
            await withCheckedContinuation { continuation in
                permissionContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
            refreshAuthStatusFromSystem()
        case .denied, .restricted:
            UserDefaults.standard.set(true, forKey: WeatherPersistence.locationDeniedKey)
            await locateViaIP()
            return
        case .authorized:
            break
        }

        guard authStatus == .authorized else {
            await locateViaIP()
            return
        }

        if let resolved = await requestSingleLocation() {
            coordinate = resolved
            source = .gps
            UserDefaults.standard.set(false, forKey: WeatherPersistence.locationDeniedKey)
            await resolveCityName(for: resolved)
            persistLocation()
            return
        }

        await locateViaIP()
    }

    func locateManually(city: String) async {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Veuillez saisir une ville."
            return
        }

        isLocating = true
        lastError = nil
        defer { isLocating = false }

        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
            guard let location = placemarks.first?.location?.coordinate else {
                lastError = "Ville introuvable : \(trimmed)"
                return
            }
            coordinate = location
            cityName = placemarks.first?.locality ?? trimmed
            source = .manual(cityName ?? trimmed)
            UserDefaults.standard.set(cityName, forKey: WeatherPersistence.userCityKey)
            persistLocation()
        } catch {
            lastError = "Géocodage impossible : \(error.localizedDescription)"
        }
    }

    func locateViaIP() async {
        isLocating = true
        lastError = nil
        defer { isLocating = false }

        guard let url = URL(string: "https://ipapi.co/json/") else {
            applyDefault()
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                applyDefault()
                return
            }
            let decoded = try JSONDecoder().decode(IPApiResponse.self, from: data)
            coordinate = CLLocationCoordinate2D(latitude: decoded.latitude, longitude: decoded.longitude)
            cityName = decoded.city
            source = .ip
            persistLocation()
        } catch {
            applyDefault()
        }
    }

    func applyDefault() {
        coordinate = CLLocationCoordinate2D(
            latitude: WeatherPersistence.defaultLatitude,
            longitude: WeatherPersistence.defaultLongitude
        )
        cityName = WeatherPersistence.defaultCityName
        source = .default
        persistLocation()
    }

    // MARK: - Helpers

    private func refreshAuthStatusFromSystem() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            authStatus = .notDetermined
        case .denied:
            authStatus = .denied
        case .restricted:
            authStatus = .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            authStatus = .authorized
        @unknown default:
            authStatus = .notDetermined
        }
    }

    private func requestSingleLocation() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            locateContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func resolveCityName(for coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            cityName = placemarks.first?.locality
                ?? placemarks.first?.subAdministrativeArea
                ?? placemarks.first?.administrativeArea
            if let cityName {
                UserDefaults.standard.set(cityName, forKey: WeatherPersistence.userCityKey)
            }
        } catch {
            cityName = String(format: "%.2f°N %.2f°E", coordinate.latitude, coordinate.longitude)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refreshAuthStatusFromSystem()
            permissionContinuation?.resume()
            permissionContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in
            locateContinuation?.resume(returning: coord)
            locateContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastError = error.localizedDescription
            locateContinuation?.resume(returning: nil)
            locateContinuation = nil
        }
    }
}

// MARK: - ipapi.co

private struct IPApiResponse: Decodable, Sendable {
    let city: String?
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case city
        case latitude
        case longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        latitude = try c.decodeFlexibleDouble(forKey: .latitude)
        longitude = try c.decodeFlexibleDouble(forKey: .longitude)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let text = try? decode(String.self, forKey: key), let value = Double(text) { return value }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Nombre attendu")
    }
}
