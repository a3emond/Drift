import SwiftUI
import PhotosUI

struct BottleDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: BottleDetailViewModel

    @State private var pickedPhoto: PhotosPickerItem?

    init(
        bottleId: String,
        distanceKm: Double,
        distanceCategory: String,
        bottleService: BottleServiceProtocol,
        authService: FirebaseAuthService,
        chatService: ChatService,
        storage: StorageService,
        logger: Logging
    ) {
        _vm = StateObject(
            wrappedValue: BottleDetailViewModel(
                bottleId: bottleId,
                distanceKm: distanceKm,
                distanceCategory: distanceCategory,
                bottleService: bottleService,
                authService: authService,
                chatService: chatService,
                storage: storage,
                logger: logger
            )
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Bottle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .onChange(of: pickedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else { return }
                    try await vm.sendChatImageData(data)
                } catch {
                    vm.presentChatUXError(error)
                }
                pickedPhoto = nil
            }
        }
        .alert(
            "Chat error",
            isPresented: Binding(
                get: { vm.chatUXErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { vm.clearChatUXError() }
                }
            )
        ) {
            Button("OK") { vm.clearChatUXError() }
        } message: {
            Text(vm.chatUXErrorMessage ?? "")
        }
    }

    // --------------------------------------------------
    // MARK: - Main Content
    // --------------------------------------------------

    @ViewBuilder
    private var content: some View {

        if vm.isLoading {
            ProgressView().padding()
        } else if let err = vm.errorMessage {
            Text(err)
                .foregroundColor(.secondary)
                .padding()
        } else {
            switch vm.state {

            case .loading:
                ProgressView().padding()

            case .expired:
                VStack(spacing: 12) {
                    Text("Expired").font(.headline)
                    Text("This bottle is no longer available.")
                        .foregroundColor(.secondary)
                }
                .padding()

            case .error(let message):
                VStack(spacing: 12) {
                    Text("Error").font(.headline)
                    Text(message).foregroundColor(.secondary)
                }
                .padding()

            case .locked(let reason):
                lockedView(reason: reason)

            case .unlocked:
                unlockedView()
            }
        }
    }

    // --------------------------------------------------
    // MARK: - Locked View
    // --------------------------------------------------

    private func lockedView(reason: LockReason) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            VStack(alignment: .leading, spacing: 6) {
                Text("Locked").font(.headline)
                Text(lockReasonText(reason))
                    .foregroundColor(.secondary)

                Text("Distance: \(vm.distanceKm, specifier: "%.2f") km")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if shouldShowPasswordField(reason: reason) {
                SecureField("Password", text: $vm.passwordInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Button("Unlock") {
                vm.attemptUnlock()
            }
            .buttonStyle(.borderedProminent)

            Divider()

            if let id = vm.bottle?.owner_uid {
                Text("Owner: \(id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func shouldShowPasswordField(reason: LockReason) -> Bool {
        switch reason {
        case .passwordRequired, .passwordIncorrect:
            return true
        default:
            return vm.bottle?.conditions.password?.isEmpty == false
        }
    }

    // --------------------------------------------------
    // MARK: - Unlocked View
    // --------------------------------------------------

    private func unlockedView() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if let b = vm.bottle {

                        if let text = b.content.text,
                           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                        }

                        if let url = vm.imageDownloadURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().padding(.vertical)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(12)
                                case .failure:
                                    Text("Failed to load image")
                                        .foregroundColor(.secondary)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

                        if b.content.audio_path != nil {
                            Text("Audio attached (playback wiring next)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        if b.chat_enabled {
                            Divider()
                            chatView(scrollProxy: proxy)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding()
            }
        }
    }

    // --------------------------------------------------
    // MARK: - Chat (Grouped + Aligned + Avatar + Timestamp)
    // --------------------------------------------------

    private func chatView(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chat").font(.headline)

            if vm.chatMessages.isEmpty {
                Text("No messages yet.")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(vm.chatBubbles) { item in
                        ChatBubbleView(item: item)
                            .id(item.id)
                    }
                }
                .onChange(of: vm.chatMessages.count) { _, _ in
                    guard let last = vm.chatBubbles.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollProxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            composerBar()
        }
    }

    private func composerBar() -> some View {
        HStack(spacing: 8) {

            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Image(systemName: "photo")
            }
            .disabled(vm.isBusy)

            Button {
                if vm.isRecording {
                    vm.stopAudioRecording()
                } else {
                    vm.startAudioRecording()
                }
            } label: {
                Image(systemName: vm.isRecording ? "stop.circle" : "mic")
            }
            .disabled(vm.isBusy)

            TextField("Message…", text: $vm.chatInputText)
                .textFieldStyle(.roundedBorder)
                .disabled(vm.isBusy)

            Button("Send") {
                vm.sendChatText()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                vm.isBusy ||
                vm.chatInputText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        }
    }

    

    // --------------------------------------------------
    // MARK: - Lock Text
    // --------------------------------------------------

    private func lockReasonText(_ reason: LockReason) -> String {
        switch reason {

        case .passwordRequired:
            return "Password required."

        case .passwordIncorrect:
            return "Password incorrect."

        case .tooFar(let maxKm, let actualKm):
            return String(format: "Too far. Max %.2f km, you are %.2f km.", maxKm, actualKm)

        case .tooClose(let minKm, let actualKm):
            return String(format: "Too close. Min %.2f km, you are %.2f km.", minKm, actualKm)

        case .timeLocked(let unlockAt):
            let d = Date(timeIntervalSince1970: unlockAt)
            return "Locked until \(d.formatted(date: .abbreviated, time: .shortened))."

        case .timeWindow(let start, let end):
            let s = start.map {
                Date(timeIntervalSince1970: $0)
                    .formatted(date: .abbreviated, time: .shortened)
            } ?? "any"

            let e = end.map {
                Date(timeIntervalSince1970: $0)
                    .formatted(date: .abbreviated, time: .shortened)
            } ?? "any"

            return "Available only between \(s) and \(e)."

        case .weatherLocked:
            return "Weather requirement not met."

        case .unknown:
            return "Ready to unlock."
        }
    }
}
