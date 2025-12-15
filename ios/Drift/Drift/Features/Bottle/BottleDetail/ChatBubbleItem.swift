import Foundation

struct ChatBubbleItem: Identifiable {
    let id: String
    let text: String?
    let imagePath: String?
    let audioPath: String?
    let timestamp: TimeInterval

    let isMine: Bool
    let distanceLabel: String

    let isFirstInGroup: Bool
}
