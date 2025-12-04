namespace Drift.Worker.Models;

public sealed class DriftUser
{
    public long created_at { get; set; }
    public long last_active { get; set; }

    public UserSettings settings { get; set; } = new();
    public UserEconomy economy { get; set; } = new();
    public UserEntitlements entitlements { get; set; } = new();
    public UserStats stats { get; set; } = new();
}

public sealed class UserSettings
{
    public string chat_color { get; set; } = "";
    public string avatar_style { get; set; } = "";
    public string language { get; set; } = "";
}

public sealed class UserEconomy
{
    public int coins { get; set; }
    public int bottle_tokens { get; set; }
    public long daily_loot_timestamp { get; set; }
}

public sealed class UserEntitlements
{
    public bool premium_user { get; set; }
    public UnlockedBottleTypes unlocked_bottle_types { get; set; } = new();
}

public sealed class UnlockedBottleTypes
{
    public bool time_locked { get; set; }
    public bool weather_locked { get; set; }
    public bool whisper_bottle { get; set; }
    public bool multi_media_bottle { get; set; }
    public bool rare_bottle_theme { get; set; }
}

public sealed class UserStats
{
    public int bottles_created { get; set; }
    public int bottles_opened { get; set; }
    public double distance_traveled_total_km { get; set; }
    public int chat_messages_sent { get; set; }
}