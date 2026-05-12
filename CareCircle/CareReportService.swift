import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Care report metadata (no PDF upload; PDF stored locally only)

struct CareReportMetadata: Identifiable {
    let id: String
    let caregiverId: String
    let date: Date
    let localPDFPath: String
    let intensity: String
    let status: String
    let createdAt: Date

    init(
        id: String,
        caregiverId: String,
        date: Date,
        localPDFPath: String,
        intensity: String,
        status: String = "draft",
        createdAt: Date
    ) {
        self.id = id
        self.caregiverId = caregiverId
        self.date = date
        self.localPDFPath = localPDFPath
        self.intensity = intensity
        self.status = status
        self.createdAt = createdAt
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let caregiverId = data["caregiverId"] as? String,
              let localPDFPath = data["localPDFPath"] as? String,
              let intensity = data["intensity"] as? String else {
            return nil
        }
        let date: Date
        if let ts = data["date"] as? Timestamp {
            date = ts.dateValue()
        } else if let s = data["date"] as? String, let d = ISO8601DateFormatter().date(from: s) {
            date = d
        } else {
            date = Date()
        }
        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else {
            createdAt = Date()
        }
        self.id = document.documentID
        self.caregiverId = caregiverId
        self.date = date
        self.localPDFPath = localPDFPath
        self.intensity = intensity
        self.status = data["status"] as? String ?? "draft"
        self.createdAt = createdAt
    }
}

/// Saves care report metadata to Firestore. Does not upload PDFs.
final class CareReportService {
    static let shared = CareReportService()
    private let db = Firestore.firestore()

    private init() {}

    /// Saves report metadata to `careReports` collection. Call after generating and saving PDF locally.
    func saveReportMetadata(
        caregiverId: String,
        date: Date,
        localPDFPath: String,
        intensity: String,
        status: String = "draft"
    ) async throws -> String {
        let ref = db.collection("careReports").document()
        let data: [String: Any] = [
            "caregiverId": caregiverId,
            "date": Timestamp(date: date),
            "localPDFPath": localPDFPath,
            "intensity": intensity,
            "status": status,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await ref.setData(data)
        return ref.documentID
    }
}
