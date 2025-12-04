import Foundation

final class UserService {

    private let db: RealtimeDatabaseService
    private let logger: Logging

    init(db: RealtimeDatabaseService,
         logger: Logging = DriftLogger.shared) {
        self.db = db
        self.logger = logger
    }

    // MARK: - Observe / Fetch

    func observe(uid: String) -> AsyncStream<DriftUser?> {
        db.observe(DriftUser.self,
                   at: .users(.root(uid: uid)))
    }

    func fetch(uid: String) async throws -> DriftUser? {
        try await db.get(DriftUser.self,
                         at: .users(.root(uid: uid)))
    }

    // MARK: - Create initial profile

    func createInitial(uid: String,
                       language: String,
                       chatColor: String,
                       avatarStyle: String) async throws {
        logger.info("UserService.createInitial uid=\(uid)",
                    category: .database)

        let user = DriftUser.initial(
            language: language,
            chatColor: chatColor,
            avatarStyle: avatarStyle
        )

        try await db.set(user,
                         at: .users(.root(uid: uid)))
    }

    // MARK: - Ensure exists (for Apple / Google)

    func ensureExists(uid: String,
                      defaultLanguage: String) async throws {
        if let _ = try await fetch(uid: uid) {
            return
        }

        try await createInitial(
            uid: uid,
            language: defaultLanguage,
            chatColor: "default",
            avatarStyle: "default"
        )
    }

    // MARK: - Updates

    func updateSettings(uid: String,
                        _ settings: UserSettings) async throws {
        try await db.update(
            ["settings": settings.firebaseObject],
            at: .users(.root(uid: uid))
        )
    }

    func updateLastActive(uid: String) async throws {
        try await db.update(
            ["last_active": Date().timeIntervalSince1970],
            at: .users(.root(uid: uid))
        )
    }
}
