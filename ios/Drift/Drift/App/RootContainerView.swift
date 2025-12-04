import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            switch coordinator.rootRoute {
            case .launching:
                LaunchScreenView()
            case .unauthenticated:
                AuthView(flows: env.flows)
            case .mainTabs:
                RootTabView()
            }
        }
        .onAppear { coordinator.start() }
    }
}
