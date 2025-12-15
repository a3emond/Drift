import Foundation
import UIKit

@MainActor
final class NewBottleSheetViewModel: ObservableObject {

    // --------------------------------------------------
    // MARK: - State
    // --------------------------------------------------

    @Published private(set) var step: BottleCreationStep = .locationConfirm
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var errorMessage: String?

    @Published private(set) var isRecordingAudio: Bool = false

    @Published var draft: BottleDraft

    // --------------------------------------------------
    // MARK: - Dependencies
    // --------------------------------------------------

    private let bottleService: BottleServiceProtocol
    private let storage: StorageService
    private let media: MediaDraftServiceProtocol
    private let logger: Logging

    // --------------------------------------------------
    // MARK: - Init
    // --------------------------------------------------

    init(
        initialDraft: BottleDraft,
        bottleService: BottleServiceProtocol,
        storage: StorageService,
        media: MediaDraftServiceProtocol,
        logger: Logging
    ) {
        self.draft = initialDraft
        self.bottleService = bottleService
        self.storage = storage
        self.media = media
        self.logger = logger
    }

    

    // --------------------------------------------------
    // MARK: - Navigation
    // --------------------------------------------------

    func advance() {
        switch step {
        case .locationConfirm:
            step = .content
        case .content:
            step = .conditions
        case .conditions:
            step = .review
        case .review:
            submit()
        default:
            break
        }
    }

    func goBack() {
        switch step {
        case .content:
            step = .locationConfirm
        case .conditions:
            step = .content
        case .review:
            step = .conditions
        default:
            break
        }
    }

    // --------------------------------------------------
    // MARK: - Media Actions
    // --------------------------------------------------

    func addPhotoFromCamera(_ image: UIImage) {
        do {
            media.deleteFileIfExists(draft.imageLocalURL)
            draft.imageLocalURL = try media.persistImageJPEG(image, quality: 0.85)
        } catch {
            present(error)
        }
    }

    func addPhotoFromLibraryData(_ data: Data) {
        do {
            guard let img = UIImage(data: data) else {
                throw MediaDraftError.imageEncodingFailed
            }
            addPhotoFromCamera(img)
        } catch {
            present(error)
        }
    }

    func removePhoto() {
        media.deleteFileIfExists(draft.imageLocalURL)
        draft.imageLocalURL = nil
    }

    func startAudioRecording() {
        guard !isBusy else { return }

        isRecordingAudio = true

        Task {
            do {
                try await media.startAudioRecording()
            } catch {
                isRecordingAudio = false
                present(error)
            }
        }
    }

    func stopAudioRecording() {
        do {
            let url = try media.stopAudioRecording()
            isRecordingAudio = false

            media.deleteFileIfExists(draft.audioLocalURL)
            draft.audioLocalURL = url
        } catch {
            isRecordingAudio = false
            present(error)
        }
    }

    func removeAudio() {
        media.deleteFileIfExists(draft.audioLocalURL)
        draft.audioLocalURL = nil
    }

    // --------------------------------------------------
    // MARK: - Submit
    // --------------------------------------------------

    private func submit() {
        guard !isBusy else { return }

        isBusy = true
        errorMessage = nil
        step = .submitting

        Task {
            do {
                try draft.validateForSubmission()

                logger.info("NewBottle submit start", category: .ui)

                // Pre-generate ID so storage + db agree on the same bottleId
                let bottleId = UUID().uuidString

                let uploadedImagePath = try await uploadDraftImageIfNeeded(bottleId: bottleId)
                let uploadedAudioPath = try await uploadDraftAudioIfNeeded(bottleId: bottleId)

                let createdId = try await bottleService.createBottle(
                    id: bottleId,
                    from: draft,
                    imagePath: uploadedImagePath,
                    audioPath: uploadedAudioPath
                )

                logger.info("NewBottle submit success id=\(createdId)", category: .ui)

                // Cleanup local temp
                media.clearDraftMedia(imageURL: draft.imageLocalURL, audioURL: draft.audioLocalURL)

                isBusy = false
                step = .completed(bottleId: createdId)

            } catch {
                logger.error("NewBottle submit failed", category: .ui, error: error)
                isBusy = false
                present(error)
                step = .error(errorMessage ?? "Unknown error")
            }
        }
    }

    private func uploadDraftImageIfNeeded(bottleId: String) async throws -> String? {
        guard let url = draft.imageLocalURL else { return nil }

        let filename = StoragePath.generateFilename(ext: "jpg")
        let path = StoragePath.bottleAsset(bottleId: bottleId, filename: filename)

        _ = try await storage.uploadFile(
            url,
            to: path,
            contentType: "image/jpeg"
        )

        return path.value
    }

    private func uploadDraftAudioIfNeeded(bottleId: String) async throws -> String? {
        guard let url = draft.audioLocalURL else { return nil }

        let filename = StoragePath.generateFilename(ext: "m4a")
        let path = StoragePath.bottleAsset(bottleId: bottleId, filename: filename)

        _ = try await storage.uploadFile(
            url,
            to: path,
            contentType: "audio/m4a"
        )

        return path.value
    }

    // --------------------------------------------------
    // MARK: - Error Handling
    // --------------------------------------------------

    private func present(_ error: Error) {
        let message =
            (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription

        errorMessage = message
        step = .error(message)
    }
}
