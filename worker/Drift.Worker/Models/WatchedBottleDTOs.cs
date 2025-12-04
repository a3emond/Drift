namespace Drift.Worker.Models;

public sealed class WatchedBottle
{
    public long saved_at { get; set; }
    public bool notified_ready { get; set; }
}