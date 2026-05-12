import Foundation
import FirebaseFirestore

// MARK: - Model

struct CommunityRequest: Identifiable, Equatable {
    let id: String
    let caregiverId: String
    let caretakerNumber: String
    let title: String
    let description: String
    let createdAt: Date
    let status: Status
    let acceptedBy: String?
    let helperName: String?
    let helperPhone: String?
    let helperTime: String?
    let latitude: Double?
    let longitude: Double?

    enum Status: String, Equatable {
        case open
        case accepted
        case completed
    }

    init(
        id: String,
        caregiverId: String,
        caretakerNumber: String,
        title: String,
        description: String,
        createdAt: Date,
        status: Status,
        acceptedBy: String?,
        helperName: String?,
        helperPhone: String?,
        helperTime: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.id = id
        self.caregiverId = caregiverId
        self.caretakerNumber = caretakerNumber
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.status = status
        self.acceptedBy = acceptedBy
        self.helperName = helperName
        self.helperPhone = helperPhone
        self.helperTime = helperTime
        self.latitude = latitude
        self.longitude = longitude
    }

    static func from(_ data: [String: Any], documentId: String) -> CommunityRequest? {
        guard let caregiverId = data["caregiverId"] as? String,
              let caretakerNumber = data["caretakerNumber"] as? String,
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let statusRaw = data["status"] as? String,
              let status = Status(rawValue: statusRaw) else { return nil }
        let acceptedBy = data["acceptedBy"] as? String
        let helperName = data["helperName"] as? String
        let helperPhone = data["helperPhone"] as? String
        let helperTime = data["helperTime"] as? String
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        return CommunityRequest(
            id: documentId,
            caregiverId: caregiverId,
            caretakerNumber: caretakerNumber,
            title: title,
            description: description,
            createdAt: createdAt,
            status: status,
            acceptedBy: acceptedBy,
            helperName: helperName,
            helperPhone: helperPhone,
            helperTime: helperTime,
            latitude: latitude,
            longitude: longitude
        )
    }
}
