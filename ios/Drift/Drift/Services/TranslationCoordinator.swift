//
//  TranslationCoordinator.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-13.
//


import Foundation

#if canImport(Translation)
import Translation
#endif

@MainActor
final class TranslationCoordinator {

    private let db: RealtimeDatabaseService
    private let logger: Logging

    #if canImport(Translation)
    private var session: TranslationSession?
    #endif

    init(db: RealtimeDatabaseService,
         logger: Logging = DriftLogger.shared) {
        self.db = db
        self.logger = logger
    }

    #if canImport(Translation)
    func bind(session: TranslationSession) {
        self.session = session
    }
    #endif

    // MARK: - Chat message writeback

    func translateChatMessageIfNeeded(
        bottleId: String,
        messageId: String,
        message: ChatMessage,
        targetLang: String
    ) async {
        guard let original = message.text, !original.isEmpty else { return }

        // Already translated for this target
        if let mem = message.translation_memory, mem[targetLang] != nil { return }

        #if canImport(Translation)
        guard let session else { return }

        do {
            let response = try await session.translate(original)
            let translated = response.targetText

            if translated.isEmpty || translated == original { return }

            var newMem = message.translation_memory ?? [:]
            newMem[targetLang] = translated

            try await db.update(
                ["translation_memory": newMem],
                at: .chats(.message(bottleId: bottleId, messageId: messageId))
            )
        } catch {
            logger.warning("translateChatMessageIfNeeded failed",
                           category: .app,
                           error: error)
        }
        #endif
    }
}
