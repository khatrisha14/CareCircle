import Foundation
import FirebaseFirestore

// MARK: - Model

struct Message: Identifiable, Equatable {
    let id: String
    let requestId: String
    let senderId: String
    let text: String?
    let type: MessageType
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date

    enum MessageType: String, Equatable {
        case text
        case system
        case location
    }

    init(id: String, requestId: String, senderId: String, text: String?, type: MessageType, latitude: Double?, longitude: Double?, createdAt: Date) {
        self.id = id
        self.requestId = requestId
        self.senderId = senderId
        self.text = text
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    static func from(_ data: [String: Any], documentId: String) -> Message? {
        guard let requestId = data["requestId"] as? String,
              let senderId = data["senderId"] as? String else { return nil }
        let typeRaw = data["type"] as? String ?? "text"
        let type = MessageType(rawValue: typeRaw) ?? .text
        let text = data["text"] as? String
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        return Message(
            id: documentId,
            requestId: requestId,
            senderId: senderId,
            text: text,
            type: type,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt
        )
    }
}

// MARK: - Timestamp formatting

enum MessageTimestampFormatter {
    /// "Just now" (<1 min), "2:45 PM", "Yesterday", or short date if older.
    static func format(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let diff = now.timeIntervalSince(date)
        if diff < 60, diff >= 0 {
            return "Just now"
        }
        if cal.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        if cal.isDateInYesterday(date) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
