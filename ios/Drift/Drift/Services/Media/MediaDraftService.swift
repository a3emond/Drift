//
//  MediaDraftService.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-15.
//


import Foundation
import UIKit
import AVFoundation

final class MediaDraftService: NSObject, MediaDraftServiceProtocol {

    private let logger: Logging

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    init(logger: Logging = DriftLogger.shared) {
        self.logger = logger
        super.init()
    }

    // ----------------------------------------------------------
    // MARK: - Image Persistence
    // ----------------------------------------------------------

    func persistImageJPEG(_ image: UIImage, quality: CGFloat = 0.85) throws -> URL {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw MediaDraftError.imageEncodingFailed
        }

        let dir = try ensureDraftDir()
        let filename = StoragePath.generateFilename(ext: "jpg")
        let url = dir.appendingPathComponent(filename)

        try data.write(to: url, options: [.atomic])

        logger.info("MediaDraftService.persistImageJPEG saved \(url.lastPathComponent)", category: .storage)
        return url
    }

    // ----------------------------------------------------------
    // MARK: - Audio Permission
    // ----------------------------------------------------------

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // ----------------------------------------------------------
    // MARK: - Audio Recording
    // ----------------------------------------------------------

    func startAudioRecording() async throws {
        if recorder != nil {
            throw MediaDraftError.recordingAlreadyInProgress
        }

        let granted = await requestMicrophonePermission()
        guard granted else {
            throw MediaDraftError.microphonePermissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])

        let dir = try ensureDraftDir()
        let filename = StoragePath.generateFilename(ext: "m4a")
        let url = dir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw MediaDraftError.recordingStartFailed
        }

        self.recorder = recorder
        self.recordingURL = url

        logger.info("MediaDraftService.startAudioRecording started \(url.lastPathComponent)", category: .ui)
    }

    func stopAudioRecording() throws -> URL {
        guard let recorder else {
            throw MediaDraftError.noActiveRecording
        }

        recorder.stop()
        self.recorder = nil

        guard let url = recordingURL else {
            throw MediaDraftError.recordingStopFailed
        }

        logger.info("MediaDraftService.stopAudioRecording stopped \(url.lastPathComponent)", category: .ui)
        return url
    }

    func cancelAudioRecording() {
        recorder?.stop()
        recorder = nil

        if let url = recordingURL {
            deleteFileIfExists(url)
        }

        recordingURL = nil
        logger.info("MediaDraftService.cancelAudioRecording", category: .ui)
    }

    // ----------------------------------------------------------
    // MARK: - Cleanup
    // ----------------------------------------------------------

    func deleteFileIfExists(_ url: URL?) {
        guard let url else { return }

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                logger.info("MediaDraftService.deleteFileIfExists deleted \(url.lastPathComponent)", category: .storage)
            }
        } catch {
            logger.error("MediaDraftService.deleteFileIfExists failed", category: .storage, error: error)
        }
    }

    func clearDraftMedia(imageURL: URL?, audioURL: URL?) {
        deleteFileIfExists(imageURL)
        deleteFileIfExists(audioURL)
    }
    

    // ----------------------------------------------------------
    // MARK: - Private
    // ----------------------------------------------------------

    private func ensureDraftDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DriftMediaDraft", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return dir
    }
}

extension MediaDraftService: AVAudioRecorderDelegate {}
extension MediaDraftService {

    func clearAllDraftMedia() {
        // Remove everything under DriftMediaDraft/
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DriftMediaDraft", isDirectory: true)

        do {
            if FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.removeItem(at: dir)
                logger.info("MediaDraftService.clearAllDraftMedia()", category: .storage)
            }
        } catch {
            logger.error(
                "MediaDraftService.clearAllDraftMedia failed",
                category: .storage,
                error: error
            )
        }
    }
}

enum MediaDraftError: LocalizedError {
    case imageEncodingFailed
    case microphonePermissionDenied
    case recordingAlreadyInProgress
    case recordingStartFailed
    case noActiveRecording
    case recordingStopFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode image"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .recordingAlreadyInProgress:
            return "Recording already in progress"
        case .recordingStartFailed:
            return "Failed to start recording"
        case .noActiveRecording:
            return "No active recording"
        case .recordingStopFailed:
            return "Failed to stop recording"
        }
    }
}
