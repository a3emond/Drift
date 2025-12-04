namespace Drift.Worker.Models;

public sealed class Bottle
{
    public string owner_uid { get; set; } = "";
    public long created_at { get; set; }
    public long? expires_at { get; set; }
    public long? opened_at { get; set; }

    public BottleLocation location { get; set; } = new();
    public BottleConditions conditions { get; set; } = new();
    public BottleContent content { get; set; } = new();

    public bool chat_enabled { get; set; }
    public BottleStatus status { get; set; } = new();
}

public sealed class BottleLocation
{
    public double lat { get; set; }
    public double lng { get; set; }
}

public sealed class BottleConditions
{
    public string? password { get; set; }
    public TimeWindow time_window { get; set; } = new();
    public WeatherCondition weather { get; set; } = new();

    public bool exact_location { get; set; }

    public double? distance_min { get; set; }
    public double? distance_max { get; set; }

    public long? unlock_at_time { get; set; }
    public bool one_shot { get; set; }
}

public sealed class TimeWindow
{
    public long? start { get; set; }
    public long? end { get; set; }
}

public sealed class WeatherCondition
{
    public string? type { get; set; }
    public double? threshold { get; set; }
}

public sealed class BottleContent
{
    public string? text { get; set; }
    public string? image_path { get; set; }
    public string? audio_path { get; set; }
}

public sealed class BottleStatus
{
    public bool locked { get; set; }
    public bool dead { get; set; }
    public long alive_until { get; set; }
    public int active_users_count { get; set; }
}