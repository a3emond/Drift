import SwiftUI

// --- Containers --- //
final class AppEnvironmentContainer: ObservableObject {
    @Published var value: AppEnvironment? = nil
}

final class AppCoordinatorContainer: ObservableObject {
    @Published var value: AppCoordinator? = nil
}

// --- App Entry Point --- //
@main
struct DriftApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var appEnvironment = AppEnvironmentContainer()
    @StateObject private var appCoordinator = AppCoordinatorContainer()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let env = appEnvironment.value, let coord = appCoordinator.value {
                RootContainerView()
                    .environmentObject(env)
                    .environmentObject(coord)
                    .onChange(of: scenePhase) { _, newPhase in
                        coord.handleScenePhaseChange(newPhase)
                    }
            } else {
                LaunchScreenView()
                    .onAppear { bootstrap() }
            }
        }
    }

    private func bootstrap() {
        let env = AppEnvironment()
        appEnvironment.value = env
        appCoordinator.value = AppCoordinator(environment: env)
    }
}
