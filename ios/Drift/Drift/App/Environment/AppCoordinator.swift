import SwiftUI
import Combine

@Observable
final class AppCoordinator: ObservableObject {

    enum RootRoute {
        case launching
        case unauthenticated
        case mainTabs
    }

    private(set) var rootRoute: RootRoute = .launching

    @ObservationIgnored
    private let environment: AppEnvironment

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var hasStarted = false

    init(environment: AppEnvironment) {
        self.environment = environment

        NotificationCenter.default.publisher(for: .appDidEnterBackground)
            .sink { [weak self] _ in self?.handleAppDidEnterBackground() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appWillEnterForeground)
            .sink { [weak self] _ in self?.handleAppWillEnterForeground() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appWillTerminate)
            .sink { [weak self] _ in self?.handleAppWillTerminate() }
            .store(in: &cancellables)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        environment.auth.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                self.rootRoute = (user == nil) ? .unauthenticated : .mainTabs
            }
            .store(in: &cancellables)
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:     handleAppBecameActive()
        case .inactive:   handleAppBecameInactive()
        case .background: handleAppMovedToBackground()
        @unknown default: break
        }
    }

    private func handleAppBecameActive() {}
    private func handleAppBecameInactive() {
        environment.mediaDraft.clearAllDraftMedia()
    }
    private func handleAppMovedToBackground() {}

    func routeToUnauthenticated() { rootRoute = .unauthenticated }
    func routeToMainTabs()        { rootRoute = .mainTabs }

    private func handleAppDidEnterBackground() {
        environment.mediaDraft.clearAllDraftMedia()
    }
    private func handleAppWillEnterForeground() {}
    private func handleAppWillTerminate() {
        environment.mediaDraft.clearAllDraftMedia()
    }
}
