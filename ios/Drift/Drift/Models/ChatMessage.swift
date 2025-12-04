import Foundation

struct ChatMessage: Codable {
    var uid: String
    var text: String?
    var image_path: String?
    var audio_path: String?
    var timestamp: TimeInterval
    var distance_category: String
    var translation_memory: [String: String]?
}
