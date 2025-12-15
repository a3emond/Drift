import Foundation

// ------------------------------------------------------
// MARK: - Access State
// ------------------------------------------------------

enum BottleAccessState: Equatable {
    case loading
    case expired
    case locked(reason: LockReason)
    case unlocked
    case error(String)
}

enum LockReason: Equatable {
    case passwordRequired
    case passwordIncorrect
    case tooFar(maxKm: Double, actualKm: Double)
    case tooClose(minKm: Double, actualKm: Double)
    case timeLocked(unlockAt: TimeInterval)
    case timeWindow(start: TimeInterval?, end: TimeInterval?)
    case weatherLocked
    case unknown
}

// ------------------------------------------------------
// MARK: - ViewModel
// ------------------------------------------------------

@MainActor
final class BottleDetailViewModel: ObservableObject {

    // --------------------------------------------------
    // MARK: - Published State
    // --------------------------------------------------

    @Published private(set) var isLoading: Bool = true
    @Published private(set) var errorMessage: String?

    @Published private(set) var bottle: Bottle?
    @Published private(set) var state: BottleAccessState = .loading

    @Published var passwordInput: String = ""

    @Published private(set) var imageDownloadURL: URL?
    @Published private(set) var chatMessages: [ChatMessageRecord] = []
    @Published var chatInputText: String = ""

    @Published private(set) var isRecording: Bool = false
    @Published private(set) var isBusy: Bool = false

    @Published var chatUXErrorMessage: String?

    // --------------------------------------------------
    // MARK: - Context
    // --------------------------------------------------

    let bottleId: String
    let distanceKm: Double
    let distanceCategory: String

    private let groupingInterval: TimeInterval = 120

    // --------------------------------------------------
    // MARK: - Dependencies
    // --------------------------------------------------

    private let bottleService: BottleServiceProtocol
    private let authService: FirebaseAuthService
    private let chatService: ChatService
    private let storage: StorageService
    private let logger: Logging

    // --------------------------------------------------
    // MARK: - Tasks
    // --------------------------------------------------

    private var bottleTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?

    // --------------------------------------------------
    // MARK: - Init
    // --------------------------------------------------

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
        self.bottleId = bottleId
        self.distanceKm = distanceKm
        self.distanceCategory = distanceCategory
        self.bottleService = bottleService
        self.authService = authService
        self.chatService = chatService
        self.storage = storage
        self.logger = logger
    }

    // --------------------------------------------------
    // MARK: - Lifecycle
    // --------------------------------------------------

    func start() {
        logger.info("BottleDetailViewModel.start id=\(bottleId)", category: .ui)
        observeBottle()
    }

    func stop() {
        bottleTask?.cancel()
        bottleTask = nil

        chatTask?.cancel()
        chatTask = nil

        isBusy = false
        isRecording = false
    }

    // --------------------------------------------------
    // MARK: - Observe Bottle
    // --------------------------------------------------

    private func observeBottle() {
        bottleTask?.cancel()

        bottleTask = Task {
            let stream = bottleService.observeBottle(bottleId: bottleId)

            for await b in stream {
                self.bottle = b
                self.isLoading = false

                guard let b else {
                    self.state = .error("Bottle not found")
                    continue
                }

                self.state = resolveState(for: b)
                await loadMediaURLsIfNeeded(from: b)

                if case .unlocked = self.state, b.chat_enabled {
                    startChatIfNeeded()
                } else {
                    stopChatIfNeeded()
                }
            }
        }
    }

    // --------------------------------------------------
    // MARK: - State Resolution
    // --------------------------------------------------

    private func resolveState(for bottle: Bottle) -> BottleAccessState {
        let now = Date().timeIntervalSince1970

        if bottle.status.dead || bottle.status.alive_until <= now {
            return .expired
        }

        if bottle.status.locked == false {
            return .unlocked
        }

        if let unlockAt = bottle.conditions.unlock_at_time, now < unlockAt {
            return .locked(reason: .timeLocked(unlockAt: unlockAt))
        }

        if let tw = bottle.conditions.time_window {
            if let s = tw.start, now < s { return .locked(reason: .timeWindow(start: s, end: tw.end)) }
            if let e = tw.end, now > e { return .locked(reason: .timeWindow(start: tw.start, end: e)) }
        }

        if let min = bottle.conditions.distance_min, distanceKm < min {
            return .locked(reason: .tooClose(minKm: min, actualKm: distanceKm))
        }

        if let max = bottle.conditions.distance_max, distanceKm > max {
            return .locked(reason: .tooFar(maxKm: max, actualKm: distanceKm))
        }

        if let w = bottle.conditions.weather, (w.type != nil || w.threshold != nil) {
            return .locked(reason: .weatherLocked)
        }

        if let pw = bottle.conditions.password, !pw.isEmpty {
            if passwordInput.isEmpty { return .locked(reason: .passwordRequired) }
            if passwordInput != pw { return .locked(reason: .passwordIncorrect) }
        }

        return .locked(reason: .unknown)
    }

    // --------------------------------------------------
    // MARK: - Unlock
    // --------------------------------------------------

    func attemptUnlock() {
        guard let b = bottle else { return }
        guard let uid = authService.currentUser?.uid else {
            state = .error("Not authenticated")
            return
        }

        let resolved = resolveState(for: b)

        if case .locked(let reason) = resolved, reason != .unknown {
            state = .locked(reason: reason)
            return
        }

        Task {
            do {
                let now = Date().timeIntervalSince1970

                try await bottleService.registerOpener(
                    bottleId: bottleId,
                    uid: uid,
                    distanceKm: distanceKm
                )

                try await bottleService.unlockBottle(
                    bottleId: bottleId,
                    openedAt: now
                )

            } catch {
                logger.error("Bottle unlock failed", category: .ui, error: error)
                state = .error(error.localizedDescription)
            }
        }
    }

    // --------------------------------------------------
    // MARK: - Media URLs
    // --------------------------------------------------

    private func loadMediaURLsIfNeeded(from bottle: Bottle) async {
        guard let imagePath = bottle.content.image_path else {
            imageDownloadURL = nil
            return
        }

        do {
            imageDownloadURL = try await storage.downloadURL(for: .raw(path: imagePath))
        } catch {
            logger.error("Bottle image downloadURL failed", category: .storage, error: error)
            imageDownloadURL = nil
        }
    }

    // --------------------------------------------------
    // MARK: - Chat
    // --------------------------------------------------

    private func startChatIfNeeded() {
        guard chatTask == nil else { return }

        chatTask = Task {
            let stream = chatService.observeMessages(bottleId: bottleId)
            for await items in stream {
                self.chatMessages = items
            }
        }
    }

    private func stopChatIfNeeded() {
        chatTask?.cancel()
        chatTask = nil
        chatMessages = []
    }

    func sendChatText() {
        guard !isBusy else { return }
        guard let uid = authService.currentUser?.uid else { return }

        let text = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isBusy = true

        Task {
            defer { self.isBusy = false }

            do {
                try await chatService.sendText(
                    bottleId: bottleId,
                    from: uid,
                    text: text,
                    distanceCategory: distanceCategory
                )
                chatInputText = ""
            } catch {
                logger.error("Chat sendText failed", category: .ui, error: error)
                presentChatUXError(error)
            }
        }
    }

    func sendChatImageData(_ data: Data) async throws {
        guard let uid = authService.currentUser?.uid else { return }
        if isBusy { return }

        isBusy = true
        defer { isBusy = false }

        try await chatService.sendImage(
            bottleId: bottleId,
            from: uid,
            jpegData: data,
            filename: "image.jpg",
            distanceCategory: distanceCategory
        )
    }

    func startAudioRecording() {
        // Placeholder: wiring to actual recorder comes next.
        guard !isBusy else { return }
        isRecording = true
    }

    func stopAudioRecording() {
        // Placeholder: wiring to actual recorder + sendAudio comes next.
        isRecording = false
    }

    // --------------------------------------------------
    // MARK: - Chat UX Helpers
    // --------------------------------------------------

    func isMineChatMessage(uid: String) -> Bool {
        uid == authService.currentUser?.uid
    }

    func presentChatUXError(_ error: Error) {
        chatUXErrorMessage = error.localizedDescription
    }

    func clearChatUXError() {
        chatUXErrorMessage = nil
    }

    var chatBubbles: [ChatBubbleItem] {
        guard let myUid = authService.currentUser?.uid else { return [] }

        var result: [ChatBubbleItem] = []

        for (index, record) in chatMessages.enumerated() {
            let msg = record.message
            let isMine = msg.uid == myUid
            let prev = index > 0 ? chatMessages[index - 1].message : nil

            let isFirstInGroup =
                prev == nil ||
                prev!.uid != msg.uid ||
                msg.timestamp - prev!.timestamp > groupingInterval

            result.append(
                ChatBubbleItem(
                    id: record.id,
                    text: msg.text,
                    imagePath: msg.image_path,
                    audioPath: msg.audio_path,
                    timestamp: msg.timestamp,
                    isMine: isMine,
                    distanceLabel: distanceLabel,
                    isFirstInGroup: isFirstInGroup
                )
            )
        }

        return result
    }

    var distanceLabel: String {
        String(format: "~%.1f km away", distanceKm)
    }
}

