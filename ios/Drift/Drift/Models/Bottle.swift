import Foundation

// ----------------------------------------------------------
// MARK: - Bottle Root
// ----------------------------------------------------------

struct Bottle: Codable, Equatable {
    var owner_uid: String
    var created_at: TimeInterval
    var expires_at: TimeInterval?
    var opened_at: TimeInterval?

    var location: BottleLocation
    var conditions: BottleConditions
    var content: BottleContent

    var chat_enabled: Bool
    var status: BottleStatus
}

// ----------------------------------------------------------
// MARK: - Location
// ----------------------------------------------------------

struct BottleLocation: Codable, Equatable {
    var lat: Double
    var lng: Double
}

// ----------------------------------------------------------
// MARK: - Conditions (FLEXIBLE + SAFE)
// ----------------------------------------------------------

struct BottleConditions: Codable, Equatable {
    var password: String?

    /// OPTIONAL — bottle may have no time constraints
    var time_window: TimeWindow?

    /// OPTIONAL — bottle may have no weather constraint
    var weather: WeatherCondition?

    var exact_location: Bool
    var distance_min: Double?
    var distance_max: Double?
    var unlock_at_time: TimeInterval?
    var one_shot: Bool
}

// ----------------------------------------------------------
// MARK: - Time Window
// ----------------------------------------------------------

struct TimeWindow: Codable, Equatable {
    var start: TimeInterval?
    var end: TimeInterval?
}

// ----------------------------------------------------------
// MARK: - Weather
// ----------------------------------------------------------

struct WeatherCondition: Codable, Equatable {
    var type: String?
    var threshold: Double?
}

// ----------------------------------------------------------
// MARK: - Content
// ----------------------------------------------------------

struct BottleContent: Codable, Equatable {
    var text: String?
    var image_path: String?
    var audio_path: String?
}

// ----------------------------------------------------------
// MARK: - Status
// ----------------------------------------------------------

struct BottleStatus: Codable, Equatable {
    var locked: Bool
    var dead: Bool
    var alive_until: TimeInterval
    var active_users_count: Int
}
