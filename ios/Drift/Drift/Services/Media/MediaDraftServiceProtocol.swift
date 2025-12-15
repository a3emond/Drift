import Foundation
import UIKit

protocol MediaDraftServiceProtocol: AnyObject {

    // ----------------------------------------------------------
    // MARK: - Image Persistence (local temp)
    // ----------------------------------------------------------

    func persistImageJPEG(_ image: UIImage, quality: CGFloat) throws -> URL

    // ----------------------------------------------------------
    // MARK: - Audio Recording (local temp)
    // ----------------------------------------------------------

    func requestMicrophonePermission() async -> Bool
    func startAudioRecording() async throws
    func stopAudioRecording() throws -> URL
    func cancelAudioRecording()

    // ----------------------------------------------------------
    // MARK: - Cleanup
    // ----------------------------------------------------------

    func deleteFileIfExists(_ url: URL?)
    func clearDraftMedia(imageURL: URL?, audioURL: URL?)
    func clearAllDraftMedia()
}
