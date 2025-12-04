namespace Drift.Worker.Models;

public sealed class NotificationItem
{
    public string type { get; set; } = "";
    public string bottle_id { get; set; } = "";
    public long created_at { get; set; }
    public bool seen { get; set; }
}