import Foundation

/// Lightweight string formatters used inside the Overview tab.
/// Lives next to the views that consume them; no general-purpose formatting
/// belongs here. Helper naming matches designer pulse-handoff convention.
enum Format {
    /// Convert a date to a short relative string for card timestamps.
    /// • < 1 minute  → "just now"
    /// • < 1 hour    → "Nm ago"
    /// • < 24 hours  → "Nh ago"
    /// • yesterday   → "yesterday"
    /// • < 7 days    → "Nd ago"
    /// • else        → "M-d"
    /// Future dates fall through to the "M-d" form (todo dueDate not yet reached).
    static func formatRelative(_ date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 0 {
            return monthDay(date)
        }
        let minutes = Int(interval / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        return monthDay(date)
    }

    private static func monthDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M-d"
        return f.string(from: date)
    }
}
