import Foundation

struct DriftUser: Codable {
    var created_at: TimeInterval
    var last_active: TimeInterval

    var settings: UserSettings
    var economy: UserEconomy
    var entitlements: UserEntitlements
    var stats: UserStats
}

extension DriftUser {

    static func initial(language: String,
                        chatColor: String,
                        avatarStyle: String,
                        now: TimeInterval = Date().timeIntervalSince1970) -> DriftUser {

        DriftUser(
            created_at: now,
            last_active: now,
            settings: UserSettings(
                chat_color: chatColor,
                avatar_style: avatarStyle,
                language: language
            ),
            economy: UserEconomy(
                coins: 0,
                bottle_tokens: 0,
                daily_loot_timestamp: 0
            ),
            entitlements: UserEntitlements(
                premium_user: false,
                unlocked_bottle_types: UnlockedBottleTypes(
                    time_locked: false,
                    weather_locked: false,
                    whisper_bottle: false,
                    multi_media_bottle: false,
                    rare_bottle_theme: false
                )
            ),
            stats: UserStats(
                bottles_created: 0,
                bottles_opened: 0,
                distance_traveled_total_km: 0,
                chat_messages_sent: 0
            )
        )
    }
}

struct UserSettings: Codable {
    var chat_color: String
    var avatar_style: String
    var language: String
}

struct UserEconomy: Codable {
    var coins: Int
    var bottle_tokens: Int
    var daily_loot_timestamp: TimeInterval
}

struct UserEntitlements: Codable {
    var premium_user: Bool
    var unlocked_bottle_types: UnlockedBottleTypes
}

struct UnlockedBottleTypes: Codable {
    var time_locked: Bool
    var weather_locked: Bool
    var whisper_bottle: Bool
    var multi_media_bottle: Bool
    var rare_bottle_theme: Bool
}

struct UserStats: Codable {
    var bottles_created: Int
    var bottles_opened: Int
    var distance_traveled_total_km: Double
    var chat_messages_sent: Int
}
