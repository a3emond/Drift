import SwiftUI

struct RootTabView: View {

    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        TabView {

            // --------------------------------------------------
            // Map
            // --------------------------------------------------

            MapView(env: env)
                .environmentObject(env)
            .tabItem {
                Label("Map", systemImage: "map")
            }

            // --------------------------------------------------
            // Messages
            // --------------------------------------------------

            Text("Messages")
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right")
                }

            // NOTE:
            // Messages feature not implemented yet.
            // This placeholder will be replaced by MessagesInboxView.

            // --------------------------------------------------
            // Profile
            // --------------------------------------------------
            
            ProfileView(env: env)
                .environmentObject(env)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
            
        }
    }
}
