import Foundation
import SwiftUI
import CoreLocation

// ----------------------------------------------------------
// MARK: - UI Models
// ----------------------------------------------------------

struct MapAnnotationItem: Identifiable, Equatable {
    let id: String
    let owner_uid: String?
    let latitude: Double
    let longitude: Double
    let status: BottleStatus
    let expiresAt: TimeInterval?
}

struct SelectedBottle: Identifiable, Equatable {
    let id: String
}

struct NewBottleDraft: Identifiable, Equatable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
}

// ----------------------------------------------------------
// MARK: - MapViewModel
// ----------------------------------------------------------

@MainActor
final class MapViewModel: ObservableObject {

    // ------------------------------------------------------
    // MARK: - Published UI State
    // ------------------------------------------------------

    @Published private(set) var annotations: [MapAnnotationItem] = []
    @Published private(set) var userLocation: UserLocation?
    @Published private(set) var locationAuthorization: LocationAuthorizationState = .notDetermined
    @Published private(set) var shouldCenterOnUser: Bool = false

    @Published var selectedBottle: SelectedBottle?
    @Published var newBottleDraft: NewBottleDraft?

    @Published private(set) var activeFilter: MapFilter = .all
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var errorMessage: String?

    // ------------------------------------------------------
    // MARK: - Dependencies
    // ------------------------------------------------------

    private let authService: FirebaseAuthService
    private let locationService: LocationServiceProtocol
    let bottleService: BottleServiceProtocol
    private let logger: Logging

    // ------------------------------------------------------
    // MARK: - Tasks
    // ------------------------------------------------------

    private var locationTask: Task<Void, Never>?
    private var bottleTask: Task<Void, Never>?

    // ------------------------------------------------------
    // MARK: - Init
    // ------------------------------------------------------

    init(
        authService: FirebaseAuthService,
        locationService: LocationServiceProtocol,
        bottleService: BottleServiceProtocol,
        logger: Logging = DriftLogger.shared
    ) {
        self.authService = authService
        self.locationService = locationService
        self.bottleService = bottleService
        self.logger = logger
    }

    // ------------------------------------------------------
    // MARK: - Lifecycle
    // ------------------------------------------------------

    func start() {
        logger.info("MapViewModel.start()", category: .ui)
        observeAuthorization()
        startLocationUpdates()
        observeBottles()
    }

    func stop() {
        logger.info("MapViewModel.stop()", category: .ui)
        locationTask?.cancel()
        bottleTask?.cancel()
        locationService.stopUpdates()
    }

    // ------------------------------------------------------
    // MARK: - Location
    // ------------------------------------------------------

    private func observeAuthorization() {
        locationAuthorization = locationService.authorizationState()
        if locationAuthorization == .notDetermined {
            locationService.requestAuthorization()
        }
    }

    private func startLocationUpdates() {
        locationTask = Task {
            let stream = locationService.startUpdates()
            for await location in stream {
                self.userLocation = location
                if !self.shouldCenterOnUser {
                    self.shouldCenterOnUser = true
                }
            }
        }
    }

    // ------------------------------------------------------
    // MARK: - Bottles
    // ------------------------------------------------------

    private func observeBottles() {
        bottleTask = Task {
            self.isLoading = false
            let stream = bottleService.observeAllBottles()

            for await bottles in stream {
                self.annotations = bottles.map {
                    MapAnnotationItem(
                        id: $0.id,
                        owner_uid: $0.owner_uid,
                        latitude: $0.location.lat,
                        longitude: $0.location.lng,
                        status: $0.status,
                        expiresAt: $0.expiresAt
                    )
                }
            }
        }
    }

    // ------------------------------------------------------
    // MARK: - User Actions
    // ------------------------------------------------------

    func didSelectBottle(id: String) {
        logger.info("MapViewModel.didSelectBottle id=\(id)", category: .ui)
        selectedBottle = SelectedBottle(id: id)
    }

    func beginBottleCreation(at coordinate: CLLocationCoordinate2D) {
        logger.info(
            "MapViewModel.beginBottleCreation lat=\(coordinate.latitude) lng=\(coordinate.longitude)",
            category: .ui
        )

        newBottleDraft = NewBottleDraft(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    func setFilter(_ filter: MapFilter) {
        logger.info("MapViewModel.setFilter \(filter.rawValue)", category: .ui)
        activeFilter = filter
    }

    // ------------------------------------------------------
    // MARK: - Filtering
    // ------------------------------------------------------

    var filteredAnnotations: [MapAnnotationItem] {
        let now = Date().timeIntervalSince1970

        switch activeFilter {
        case .all:
            return annotations

        case .myBottles:
            return annotations.filter {
                $0.owner_uid == authService.currentUser?.uid
            }

        case .active:
            return annotations.filter {
                !$0.status.dead &&
                !$0.status.locked &&
                $0.status.alive_until > now
            }

        case .locked:
            return annotations.filter { $0.status.locked }

        case .expired:
            return annotations.filter {
                $0.status.dead || $0.status.alive_until <= now
            }
        }
    }
}
