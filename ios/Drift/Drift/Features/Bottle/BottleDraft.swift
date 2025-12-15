import Foundation

struct BottleDraft: Equatable {

    // --------------------------------------------------
    // MARK: - Location
    // --------------------------------------------------

    var createdAt: TimeInterval = Date().timeIntervalSince1970
    var location: BottleLocation

    // --------------------------------------------------
    // MARK: - Content (local, pre-upload)
    // --------------------------------------------------

    var text: String?
    var imageLocalURL: URL?
    var audioLocalURL: URL?

    // --------------------------------------------------
    // MARK: - Conditions
    // --------------------------------------------------

    var password: String?
    var timeWindow: TimeWindow = TimeWindow(start: nil, end: nil)
    var weather: WeatherCondition = WeatherCondition(type: nil, threshold: nil)
    var exactLocation: Bool = false
    var distanceMin: Double?
    var distanceMax: Double?
    var unlockAtTime: TimeInterval?
    var oneShot: Bool = false

    // --------------------------------------------------
    // MARK: - Options
    // --------------------------------------------------

    var chatEnabled: Bool = true

    // --------------------------------------------------
    // MARK: - Validation
    // --------------------------------------------------

    func validateForSubmission() throws {
        let hasText = !(text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        if !hasText && imageLocalURL == nil && audioLocalURL == nil {
            throw BottleDraftError.emptyContent
        }

        if let min = distanceMin, let max = distanceMax, min > max {
            throw BottleDraftError.invalidDistanceRange
        }

        if let start = timeWindow.start, let end = timeWindow.end, start > end {
            throw BottleDraftError.invalidTimeWindow
        }
    }
}

// --------------------------------------------------
// MARK: - Errors
// --------------------------------------------------

enum BottleDraftError: LocalizedError {
    case emptyContent
    case invalidDistanceRange
    case invalidTimeWindow

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Bottle must contain text, image, or audio"
        case .invalidDistanceRange:
            return "Minimum distance cannot be greater than maximum distance"
        case .invalidTimeWindow:
            return "Time window start cannot be after end"
        }
    }
}

// --------------------------------------------------
// MARK: - Conversion
// --------------------------------------------------

extension BottleDraft {

    private var timeWindowPayload: TimeWindow? {
        (timeWindow.start != nil || timeWindow.end != nil) ? timeWindow : nil
    }

    private var weatherPayload: WeatherCondition? {
        (weather.type != nil || weather.threshold != nil) ? weather : nil
    }

    func toBottle(
        ownerUid: String,
        imagePath: String?,
        audioPath: String?
    ) -> Bottle {

        Bottle(
            owner_uid: ownerUid,
            created_at: createdAt,
            expires_at: nil,
            opened_at: nil,
            location: location,
            conditions: BottleConditions(
                password: password,
                time_window: timeWindowPayload,
                weather: weatherPayload,
                exact_location: exactLocation,
                distance_min: distanceMin,
                distance_max: distanceMax,
                unlock_at_time: unlockAtTime,
                one_shot: oneShot
            ),
            content: BottleContent(
                text: text?.trimmingCharacters(in: .whitespacesAndNewlines),
                image_path: imagePath,
                audio_path: audioPath
            ),
            chat_enabled: chatEnabled,
            status: BottleStatus(
                locked: true,
                dead: false,
                alive_until: Date.distantFuture.timeIntervalSince1970,
                active_users_count: 0
            )
        )
    }
}
