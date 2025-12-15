import Foundation
import FirebaseDatabase

enum ChatServiceError: Error {
    case failedToGenerateMessageId
}

final class ChatService {

    private let db: RealtimeDatabaseService
    private let storage: StorageService
    private let logger: Logging

    init(db: RealtimeDatabaseService,
         storage: StorageService,
         logger: Logging = DriftLogger.shared) {
        self.db = db
        self.storage = storage
        self.logger = logger
    }

    // ----------------------------------------------------------
    // MARK: - Observe messages
    // ----------------------------------------------------------

    func observeMessages(bottleId: String) -> AsyncStream<[ChatMessageRecord]> {
        let base: AsyncStream<[String: ChatMessage]?> = db.observe([String: ChatMessage].self,
                                                                   at: .chats(.room(bottleId: bottleId)))

        return AsyncStream { continuation in
            Task {
                for await dictOrNil in base {
                    guard let dict = dictOrNil else {
                        continuation.yield([])
                        continue
                    }

                    let items = dict.map { ChatMessageRecord(id: $0.key, message: $0.value) }
                        .sorted { $0.message.timestamp < $1.message.timestamp }

                    continuation.yield(items)
                }
            }

            continuation.onTermination = { @Sendable _ in
                self.db.removeObservers(at: .chats(.room(bottleId: bottleId)))
            }
        }
    }

    // ----------------------------------------------------------
    // MARK: - Send
    // ----------------------------------------------------------

    func sendText(bottleId: String,
                  from uid: String,
                  text: String,
                  distanceCategory: String,
                  now: TimeInterval = Date().timeIntervalSince1970) async throws -> String {

        let messageId = try generateMessageId(bottleId: bottleId)

        let msg = ChatMessage(
            uid: uid,
            text: text,
            image_path: nil,
            audio_path: nil,
            timestamp: now,
            distance_category: distanceCategory,
            translation_memory: nil
        )

        try await db.set(msg, at: .chats(.message(bottleId: bottleId, messageId: messageId)))
        return messageId
    }

    func sendImage(bottleId: String,
                   from uid: String,
                   jpegData: Data,
                   filename: String = "image.jpg",
                   distanceCategory: String,
                   now: TimeInterval = Date().timeIntervalSince1970) async throws -> String {

        let messageId = try generateMessageId(bottleId: bottleId)

        // upload first, then write db
        _ = try await storage.uploadData(
            jpegData,
            to: .chatMedia(bottleId: bottleId, messageId: messageId, filename: filename),
            contentType: "image/jpeg"
        )

        let path = StoragePath.chatMedia(bottleId: bottleId, messageId: messageId, filename: filename).value

        let msg = ChatMessage(
            uid: uid,
            text: nil,
            image_path: path,
            audio_path: nil,
            timestamp: now,
            distance_category: distanceCategory,
            translation_memory: nil
        )

        try await db.set(msg, at: .chats(.message(bottleId: bottleId, messageId: messageId)))
        return messageId
    }

    func sendAudio(bottleId: String,
                   from uid: String,
                   m4aFileURL: URL,
                   filename: String = "audio.m4a",
                   distanceCategory: String,
                   now: TimeInterval = Date().timeIntervalSince1970) async throws -> String {

        let messageId = try generateMessageId(bottleId: bottleId)

        _ = try await storage.uploadFile(
            m4aFileURL,
            to: .chatMedia(bottleId: bottleId, messageId: messageId, filename: filename),
            contentType: "audio/m4a"
        )

        let path = StoragePath.chatMedia(bottleId: bottleId, messageId: messageId, filename: filename).value

        let msg = ChatMessage(
            uid: uid,
            text: nil,
            image_path: nil,
            audio_path: path,
            timestamp: now,
            distance_category: distanceCategory,
            translation_memory: nil
        )

        try await db.set(msg, at: .chats(.message(bottleId: bottleId, messageId: messageId)))
        return messageId
    }

    // Optional: delete a single message node (media cleanup is worker responsibility)
    func deleteMessage(bottleId: String,
                       messageId: String) async throws {
        try await db.delete(at: .chats(.message(bottleId: bottleId, messageId: messageId)))
    }

    // ----------------------------------------------------------
    // MARK: - Private
    // ----------------------------------------------------------

    private func generateMessageId(bottleId: String) throws -> String {
        let ref = Database.database().reference().child("chats").child(bottleId).childByAutoId()
        guard let key = ref.key, !key.isEmpty else {
            throw ChatServiceError.failedToGenerateMessageId
        }
        return key
    }
}

// UI-friendly wrapper
struct ChatMessageRecord: Identifiable, Codable {
    let id: String
    var message: ChatMessage
}
