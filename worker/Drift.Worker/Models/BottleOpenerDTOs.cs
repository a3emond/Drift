namespace Drift.Worker.Models;

public sealed class BottleOpener
{
    public long opened_at { get; set; }
    public double distance_from_drop_km { get; set; }
}