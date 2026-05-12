import Foundation
import CoreLocation

// MARK: - CoreLocation wrapper (one-shot, no background)

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastLocation: CLLocationCoordinate2D?
    @Published private(set) var locationError: String?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 100
        authorizationStatus = manager.authorizationStatus
    }

    /// Request when-in-use permission and return current coordinates if available.
    /// Returns nil if denied/restricted or if location unavailable.
    func requestLocationAndGetCoordinates() async -> CLLocationCoordinate2D? {
        locationError = nil
        continuation?.resume(returning: nil)
        continuation = nil

        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
            return await withCheckedContinuation { cont in
                continuation = cont
                DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        if self.continuation != nil {
                            self.continuation?.resume(returning: self.lastLocation)
                            self.continuation = nil
                        }
                    }
                }
            }
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            var status = manager.authorizationStatus
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                status = manager.authorizationStatus
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    manager.requestLocation()
                    return await withCheckedContinuation { cont in
                        continuation = cont
                        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                            Task { @MainActor in
                                guard let self else { return }
                                if self.continuation != nil {
                                    self.continuation?.resume(returning: self.lastLocation)
                                    self.continuation = nil
                                }
                            }
                        }
                    }
                }
                if status == .denied || status == .restricted {
                    return nil
                }
            }
            return nil
        @unknown default:
            return nil
        }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Convert city name to coordinates using CLGeocoder.
    func geocode(city: String) async throws -> CLLocationCoordinate2D {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LocationError.emptyCity }
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(trimmed)
        guard let loc = placemarks.first?.location else { throw LocationError.geocodeFailed }
        await MainActor.run {
            lastLocation = loc.coordinate
        }
        return loc.coordinate
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            lastLocation = loc.coordinate
            locationError = nil
            continuation?.resume(returning: loc.coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = error.localizedDescription
            continuation?.resume(returning: lastLocation)
            continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
}

enum LocationError: LocalizedError {
    case emptyCity
    case geocodeFailed

    var errorDescription: String? {
        switch self {
        case .emptyCity: return "Please enter a city name."
        case .geocodeFailed: return "Could not find that city. Try a different name."
        }
    }
}
