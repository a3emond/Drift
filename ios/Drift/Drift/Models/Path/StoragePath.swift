import Foundation

enum StoragePath {
    
    case userAvatar(userId: String)
    case bottleAsset(bottleId: String, filename: String)
    case chatMedia(bottleId: String, messageId: String, filename: String)
    case temp(filename: String)                 // optional helper
    case raw(path: String)                      // escape hatch only

    var value: String {
        switch self {
        case .userAvatar(let uid):
            return "users/\(uid)/avatar.jpg"

        case .bottleAsset(let bottleId, let filename):
            return "bottles/\(bottleId)/assets/\(filename)"

        case .chatMedia(let bottleId, let messageId, let filename):
            return "chats/\(bottleId)/media/\(messageId)_\(filename)"

        case .temp(let filename):
            return "temp/\(filename)"

        case .raw(let path):
            return path
        }
    }

    // Generates unique filenames safely
    static func generateFilename(ext: String) -> String {
        UUID().uuidString + "." + ext
    }
}
