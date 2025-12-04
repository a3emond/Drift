import Foundation

struct NotificationItem: Codable {
    var type: String
    var bottle_id: String
    var created_at: TimeInterval
    var seen: Bool
}
