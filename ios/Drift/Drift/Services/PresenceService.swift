import Foundation

// Matches the intended Realtime DB shape: presence/{bottleId}/{uid}/{last_seen}
struct PresenceEntry: Codable {
    var last_seen: TimeInterval
}

final class PresenceService {

    private let db: RealtimeDatabaseService
    private let logger: Logging

    private var heartbeatTask: Task<Void, Never>?

    init(db: RealtimeDatabaseService,
         logger: Logging = DriftLogger.shared) {
        self.db = db
        self.logger = logger
    }

    // ----------------------------------------------------------
    // MARK: - Observe presence
    // ----------------------------------------------------------

    func observePresence(bottleId: String) -> AsyncStream<[String: PresenceEntry]?> {
        db.observe([String: PresenceEntry].self, at: .presence(.user(bottleId: bottleId, uid: "" /* unused */)))
        // NOTE: DatabasePath.Presence only exposes .user(bottleId, uid).
        // To observe the whole room, we must observe "presence/{bottleId}" directly.
        // Because DatabasePath currently does not expose that node, we use a raw path below.
    }

    func observePresenceRoom(bottleId: String) -> AsyncStream<[String: PresenceEntry]?> {
        let raw = DatabasePath(value: "presence/\(bottleId)")
        return db.observe([String: PresenceEntry].self, at: raw)
    }

    // ----------------------------------------------------------
    // MARK: - Join/Leave
    // ----------------------------------------------------------

    func setPresent(bottleId: String,
                    uid: String,
                    now: TimeInterval = Date().timeIntervalSince1970) async throws {
        let entry = PresenceEntry(last_seen: now)
        try await db.set(entry, at: .presence(.user(bottleId: bottleId, uid: uid)))
    }

    func clearPresence(bottleId: String,
                       uid: String) async throws {
        try await db.delete(at: .presence(.user(bottleId: bottleId, uid: uid)))
    }

    // ----------------------------------------------------------
    // MARK: - Heartbeat
    // ----------------------------------------------------------
    // Default best practice: run while user is inside chat; stop on leave/background.
    func startHeartbeat(bottleId: String,
                        uid: String,
                        intervalSeconds: TimeInterval = 8.0) {

        stopHeartbeat()

        heartbeatTask = Task {
            while !Task.isCancelled {
                do {
                    try await setPresent(bottleId: bottleId, uid: uid)
                } catch {
                    self.logger.warning("Presence heartbeat failed bottleId=\(bottleId) uid=\(uid)",
                                        category: .presence,
                                        error: error)
                }

                let ns = UInt64(intervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }
}
