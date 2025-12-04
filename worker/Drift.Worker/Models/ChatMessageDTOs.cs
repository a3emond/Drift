namespace Drift.Worker.Models;

public sealed class ChatMessage
{
    public string uid { get; set; } = "";
    public string? text { get; set; }
    public string? image_path { get; set; }
    public string? audio_path { get; set; }
    public long timestamp { get; set; }
    public string distance_category { get; set; } = "";
    public Dictionary<string, string>? translation_memory { get; set; }
}