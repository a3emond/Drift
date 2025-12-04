import Foundation

struct Bottle: Codable {
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

struct BottleLocation: Codable {
    var lat: Double
    var lng: Double
}

struct BottleConditions: Codable {
    var password: String?
    var time_window: TimeWindow
    var weather: WeatherCondition
    var exact_location: Bool
    var distance_min: Double?
    var distance_max: Double?
    var unlock_at_time: TimeInterval?
    var one_shot: Bool
}

struct TimeWindow: Codable {
    var start: TimeInterval?
    var end: TimeInterval?
}

struct WeatherCondition: Codable {
    var type: String?
    var threshold: Double?
}

struct BottleContent: Codable {
    var text: String?
    var image_path: String?
    var audio_path: String?
}

struct BottleStatus: Codable {
    var locked: Bool
    var dead: Bool
    var alive_until: TimeInterval
    var active_users_count: Int
}
