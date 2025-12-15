import Foundation
import CoreLocation

// ----------------------------------------------------------
// MARK: - Public Models
// ----------------------------------------------------------

enum LocationAuthorizationState: Equatable {
    case notDetermined
    case denied
    case restricted
    case authorizedForeground
    case authorizedAlways
}

struct UserLocation: Equatable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date
}

// ----------------------------------------------------------
// MARK: - Protocol
// ----------------------------------------------------------

protocol LocationServiceProtocol: AnyObject {

    /// Returns the last known authorization state.
    func authorizationState() -> LocationAuthorizationState

    /// Requests foreground authorization if needed.
    func requestAuthorization()

    /// Starts location updates and returns a stream of locations.
    /// The stream completes when `stopUpdates()` is called.
    func startUpdates() -> AsyncStream<UserLocation>

    /// Stops active location updates.
    func stopUpdates()
}

// ----------------------------------------------------------
// MARK: - LocationService
// ----------------------------------------------------------

final class LocationService: NSObject, LocationServiceProtocol {

    // ------------------------------------------------------
    // Internals
    // ------------------------------------------------------

    private let locationManager: CLLocationManager
    private let logger: Logging

    private var continuation: AsyncStream<UserLocation>.Continuation?
    private var isUpdating = false

    // ------------------------------------------------------
    // Init
    // ------------------------------------------------------

    init(logger: Logging = DriftLogger.shared) {
        self.logger = logger
        self.locationManager = CLLocationManager()

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50
    }

    // ------------------------------------------------------
    // Authorization
    // ------------------------------------------------------

    func authorizationState() -> LocationAuthorizationState {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedForeground
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization() {
        logger.info("LocationService.requestAuthorization()", category: .location)

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // ------------------------------------------------------
    // Streaming
    // ------------------------------------------------------

    func startUpdates() -> AsyncStream<UserLocation> {
        logger.info("LocationService.startUpdates()", category: .location)

        return AsyncStream { continuation in
            self.continuation = continuation

            guard self.isAuthorizedForUpdates() else {
                logger.warning(
                    "Location updates not started: not authorized",
                    category: .location
                )
                continuation.finish()
                return
            }

            self.isUpdating = true
            self.locationManager.startUpdatingLocation()

            continuation.onTermination = { @Sendable _ in
                self.stopUpdates()
            }
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }

        logger.info("LocationService.stopUpdates()", category: .location)

        isUpdating = false
        locationManager.stopUpdatingLocation()
        continuation?.finish()
        continuation = nil
    }

    // ------------------------------------------------------
    // Helpers
    // ------------------------------------------------------

    private func isAuthorizedForUpdates() -> Bool {
        switch authorizationState() {
        case .authorizedForeground, .authorizedAlways:
            return true
        default:
            return false
        }
    }
}

// ----------------------------------------------------------
// MARK: - CLLocationManagerDelegate
// ----------------------------------------------------------

extension LocationService: CLLocationManagerDelegate {

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }

        let location = UserLocation(
            latitude: last.coordinate.latitude,
            longitude: last.coordinate.longitude,
            horizontalAccuracy: last.horizontalAccuracy,
            timestamp: last.timestamp
        )

        continuation?.yield(location)

        logger.debug(
            "Location update lat=\(location.latitude) lng=\(location.longitude) acc=\(location.horizontalAccuracy)",
            category: .location
        )
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        logger.error(
            "Location update failed",
            category: .location,
            error: error
        )

        // NOTE:
        // No retry or fallback policy here.
        // Consumers (ViewModels) decide how to react to failures.
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(
            "Authorization changed: \(authorizationState())",
            category: .location
        )

        // NOTE:
        // We intentionally do not auto-start updates here.
        // The consumer controls lifecycle and intent.
    }
}
