import Foundation

final class NotificationService {

    private let db: RealtimeDatabaseService
    private let logger: Logging

    init(db: RealtimeDatabaseService,
         logger: Logging = DriftLogger.shared) {
        self.db = db
        self.logger = logger
    }

    func observeQueue(uid: String) -> AsyncStream<[NotificationRecord]> {
        let base: AsyncStream<[String: NotificationItem]?> = db.observe([String: NotificationItem].self,
                                                                        at: .notificationsQueue(.root(uid: uid)))

        return AsyncStream { continuation in
            Task {
                for await dictOrNil in base {
                    guard let dict = dictOrNil else {
                        continuation.yield([])
                        continue
                    }

                    let records = dict.map { NotificationRecord(id: $0.key, item: $0.value) }
                        .sorted { $0.item.created_at > $1.item.created_at }

                    continuation.yield(records)
                }
            }

            continuation.onTermination = { @Sendable _ in
                self.db.removeObservers(at: .notificationsQueue(.root(uid: uid)))
            }
        }
    }

    func markSeen(uid: String,
                  notificationId: String,
                  seen: Bool = true) async throws {
        try await db.update(["seen": seen],
                            at: .notificationsQueue(.notification(uid: uid, notificationId: notificationId)))
    }

    func delete(uid: String,
                notificationId: String) async throws {
        try await db.delete(at: .notificationsQueue(.notification(uid: uid, notificationId: notificationId)))
    }
}

struct NotificationRecord: Identifiable, Codable {
    let id: String
    var item: NotificationItem
}
