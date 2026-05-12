import Foundation

// MARK: - Journal entry (local only; one per calendar day)

struct JournalEntry: Codable, Identifiable, Equatable {
    /// Calendar day (start of day, UTC or local as you prefer — we use YYYY-MM-DD for storage key).
    var date: Date
    var userText: String
    var aiReflection: String
    var createdAt: Date

    var id: String { Self.dayKey(for: date) }

    /// Stable key for the calendar day (e.g. "2026-02-05").
    static func dayKey(for date: Date) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let d = c.day, let m = c.month, let y = c.year else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
