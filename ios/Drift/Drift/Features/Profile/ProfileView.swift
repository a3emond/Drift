import SwiftUI
import PhotosUI

struct ProfileView: View {

    let env: AppEnvironment

    @State private var user: DriftUser?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var pickedAvatar: PhotosPickerItem?
    @State private var isUpdating = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Profile")
        }
        .task {
            await observeUser()
        }
        .onChange(of: pickedAvatar) { _, newItem in
            guard let newItem else { return }
            Task {
                await handleAvatarPick(newItem)
                pickedAvatar = nil
            }
        }
    }

    // --------------------------------------------------
    // MARK: - Content
    // --------------------------------------------------

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().padding()
        } else if let errorMessage {
            Text(errorMessage)
                .foregroundColor(.secondary)
                .padding()
        } else if let user {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(user)
                    avatarSection(user)
                    settingsSection(user.settings)
                    entitlementsSection(user.entitlements)
                    statsSection(user.stats)
                }
                .padding()
            }
        }
    }

    // --------------------------------------------------
    // MARK: - Header
    // --------------------------------------------------

    private func header(_ user: DriftUser) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account")
                .font(.headline)

            Text(
                "Created " +
                Date(timeIntervalSince1970: user.created_at)
                    .formatted(date: .abbreviated, time: .shortened)
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // --------------------------------------------------
    // MARK: - Avatar
    // --------------------------------------------------

    private func avatarSection(_ user: DriftUser) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avatar")
                .font(.headline)

            HStack(spacing: 16) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(user.settings.avatar_style.prefix(1).uppercased())
                            .font(.title)
                            .foregroundColor(.secondary)
                    )

                PhotosPicker(selection: $pickedAvatar, matching: .images) {
                    Text("Change avatar")
                }
                .disabled(isUpdating)
            }
        }
    }

    // --------------------------------------------------
    // MARK: - Settings
    // --------------------------------------------------

    private func settingsSection(_ settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            Picker(
                "Language",
                selection: binding(
                    value: settings.language,
                    update: { settings, newValue in
                        settings.language = newValue
                    }
                )
            ) {
                Text("English").tag("en")
                Text("French").tag("fr")
            }

            Picker(
                "Chat color",
                selection: binding(
                    value: settings.chat_color,
                    update: { settings, newValue in
                        settings.chat_color = newValue
                    }
                )
            ) {
                Text("Default").tag("default")
                Text("Blue").tag("blue")
                Text("Green").tag("green")
                Text("Purple").tag("purple")
            }

            Picker(
                "Avatar style",
                selection: binding(
                    value: settings.avatar_style,
                    update: { settings, newValue in
                        settings.avatar_style = newValue
                    }
                )
            ) {
                Text("Default").tag("default")
                Text("Minimal").tag("minimal")
                Text("Bold").tag("bold")
            }
        }
    }
    // --------------------------------------------------
    // MARK: - Entitlements
    // --------------------------------------------------

    private func entitlementsSection(_ entitlements: UserEntitlements) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entitlements")
                .font(.headline)

            if entitlements.premium_user {
                Label("Premium user", systemImage: "star.fill")
                    .foregroundColor(.yellow)
            } else {
                Text("Free user")
                    .foregroundColor(.secondary)
            }
        }
    }

    // --------------------------------------------------
    // MARK: - Stats
    // --------------------------------------------------

    private func statsSection(_ stats: UserStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stats")
                .font(.headline)

            stat("Bottles created", stats.bottles_created)
            stat("Bottles opened", stats.bottles_opened)
            stat(
                "Distance traveled",
                String(format: "%.2f km", stats.distance_traveled_total_km)
            )
            stat("Messages sent", stats.chat_messages_sent)
        }
    }

    private func stat(_ title: String, _ value: CustomStringConvertible) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.description)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
    }

    // --------------------------------------------------
    // MARK: - Data
    // --------------------------------------------------

    private func observeUser() async {
        guard let uid = env.auth.currentUser?.uid else {
            errorMessage = "Not authenticated."
            isLoading = false
            return
        }

        for await user in env.users.observe(uid: uid) {
            self.user = user
            self.isLoading = false
        }
    }

    private func binding<T>(
        value: T,
        update: @escaping (inout UserSettings, T) -> Void
    ) -> Binding<T> {
        Binding(
            get: { value },
            set: { newValue in
                guard let uid = env.auth.currentUser?.uid,
                      var settings = user?.settings
                else { return }

                update(&settings, newValue)

                Task {
                    isUpdating = true
                    try? await env.users.updateSettings(uid: uid, settings)
                    isUpdating = false
                }
            }
        )
    }

    // --------------------------------------------------
    // MARK: - Avatar Upload
    // --------------------------------------------------

    private func handleAvatarPick(_ item: PhotosPickerItem) async {
        guard let uid = env.auth.currentUser?.uid else { return }

        do {
            isUpdating = true

            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else { return }

            let localURL = try env.mediaDraft.persistImageJPEG(image)

            _ = try await env.storage.uploadFile(
                localURL,
                to: .userAvatar(userId: uid),
                contentType: "image/jpeg"
            )

            env.mediaDraft.deleteFileIfExists(localURL)

        } catch {
            env.logger.error(error.localizedDescription, category: .storage)
        }

        isUpdating = false
    }
}
