import Foundation

// IMPORTANT: This model is used internally by the background worker and is not exposed to the app directly.
// Here for completeness, it is placed in the Models folder.
struct BottleCleanupEntry: Codable {
    var expires_at: TimeInterval
}
