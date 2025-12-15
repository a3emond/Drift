import Foundation

@MainActor
final class BottleDetailViewModel: ObservableObject {

    // ------------------------------------------------------
    // MARK: - Published State
    // ------------------------------------------------------

    @Published private(set) var isLoading: Bool = true
    @Published private(set) var errorMessage: String?

    // ------------------------------------------------------
    // MARK: - Identity
    // ------------------------------------------------------

    let bottleId: String

    // ------------------------------------------------------
    // MARK: - Dependencies
    // ------------------------------------------------------

    private let logger: Logging

    // ------------------------------------------------------
    // MARK: - Init
    // ------------------------------------------------------

    init(
        bottleId: String,
        logger: Logging
    ) {
        self.bottleId = bottleId
        self.logger = logger
    }

    // ------------------------------------------------------
    // MARK: - Lifecycle
    // ------------------------------------------------------

    func start() {
        logger.info("BottleDetailViewModel.start id=\(bottleId)", category: .ui)

        // NOTE:
        // This is where the following services will be used:
        // - BottleService (observe bottle)
        // - UserService (ownership, permissions)
        // - ChatService (if chat_enabled)
        // - StorageService (media loading)
        //
        // For now, we unblock UI immediately.

        isLoading = false
    }

    func dismiss() {
        // NOTE:
        // Actual dismissal is handled by SwiftUI (.sheet).
        // This method exists for symmetry and future coordinator control.
    }
}
