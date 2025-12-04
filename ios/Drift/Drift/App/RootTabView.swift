// Features/RootTabView.swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Text("Map")
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }

            Text("Messages")
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Messages")
                }

            Text("Profile")
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
    }
}
