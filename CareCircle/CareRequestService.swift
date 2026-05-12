import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Read model for caregiver's support requests

struct CareRequest: Identifiable {
    let id: String
    let caregiverId: String
    let date: Date
    let intensity: String
    let routinesCompletedCount: Int
    let routinesTotalCount: Int
    let status: String
    let strainAreas: [String]
    let routineDisruption: String
    let unexpectedEvent: String
    let unexpectedNote: String
    let supportNeeded: String
    let freeNote: String
    let questionText: String
    let replyText: String?
    let repliedAt: Date?
    let repliedBy: String?
    let createdAt: Date

    var summaryLine: String {
        "\(intensity) intensity · \(routinesCompletedCount) of \(routinesTotalCount) routines"
    }

    var isAnswered: Bool { status == "answered" }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let caregiverId = data["caregiverId"] as? String else {
            return nil
        }
        self.id = document.documentID
        self.caregiverId = caregiverId
        if let ts = data["date"] as? Timestamp {
            self.date = ts.dateValue()
        } else {
            self.date = Date()
        }
        self.intensity = data["intensity"] as? String ?? ""
        self.routinesCompletedCount = data["routinesCompletedCount"] as? Int ?? 0
        self.routinesTotalCount = data["routinesTotalCount"] as? Int ?? 0
        self.status = data["status"] as? String ?? "pending"
        self.strainAreas = data["strainAreas"] as? [String] ?? []
        self.routineDisruption = data["routineDisruption"] as? String ?? ""
        self.unexpectedEvent = data["unexpectedEvent"] as? String ?? ""
        self.unexpectedNote = data["unexpectedNote"] as? String ?? ""
        self.supportNeeded = data["supportNeeded"] as? String ?? ""
        self.freeNote = data["freeNote"] as? String ?? ""
        self.questionText = data["questionText"] as? String ?? ""
        self.replyText = data["replyText"] as? String
        if let ts = data["repliedAt"] as? Timestamp {
            self.repliedAt = ts.dateValue()
        } else {
            self.repliedAt = nil
        }
        self.repliedBy = data["repliedBy"] as? String
        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - Send payload (unchanged)

/// Sends care request metadata to Firestore (no file upload). For "Send to Social Worker" flow.
struct CareRequestPayload {
    let draft: CareReportDraft
    let completionSummary: (completed: Int, total: Int)
    let date: Date
    let questionText: String?
}

final class CareRequestService {
    static let shared = CareRequestService()
    private let db = Firestore.firestore()

    private init() {}

    /// Creates a document in `careRequests`. Does not upload any image or store local paths.
    func sendCareRequest(_ payload: CareRequestPayload) async throws {
        guard let caregiverId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CareRequestService", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to send a request."])
        }

        let draft = payload.draft
        let strainAreas = (draft.answers["q2"] as? [String]) ?? []
        let routineDisruption = draft.answers["q3"] as? String
        let unexpectedEvent = draft.answers["q4"] as? String
        let unexpectedNote = draft.answers["q5"] as? String
        let supportNeeded = draft.answers["q6"] as? String
        let freeNote = draft.answers["q7"] as? String

        let data: [String: Any] = [
            "caregiverId": caregiverId,
            "date": Timestamp(date: payload.date),
            "intensity": draft.intensity,
            "routinesCompletedCount": payload.completionSummary.completed,
            "routinesTotalCount": payload.completionSummary.total,
            "strainAreas": strainAreas,
            "routineDisruption": routineDisruption ?? "",
            "unexpectedEvent": unexpectedEvent ?? "",
            "unexpectedNote": unexpectedNote ?? "",
            "supportNeeded": supportNeeded ?? "",
            "freeNote": freeNote ?? "",
            "questionText": payload.questionText ?? "",
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]

        _ = try await db.collection("careRequests").addDocument(data: data)
    }

    /// Fetches care requests for the current caregiver, newest first.
    /// Uses caregiverId filter only (no composite index required), then sorts in memory.
    func fetchCaregiverRequests() async throws -> [CareRequest] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CareRequestService", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in."])
        }
        let snapshot = try await db.collection("careRequests")
            .whereField("caregiverId", isEqualTo: uid)
            .getDocuments()
        let list = snapshot.documents.compactMap { doc in
            CareRequest(document: doc)
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    /// Fetches pending care requests for social workers, oldest first (no composite index).
    func fetchPendingCareRequests() async throws -> [CareRequest] {
        let snapshot = try await db.collection("careRequests")
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        let list = snapshot.documents.compactMap { doc in
            CareRequest(document: doc)
        }
        return list.sorted { $0.createdAt < $1.createdAt }
    }

    /// Updates a care request with the social worker's response. Fails if status is already "answered".
    /// Uses a transaction so only one social worker can respond; adds repliedBy = current user uid.
    func respondToCareRequest(requestId: String, replyText: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CareRequestService", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to respond."])
        }
        let ref = db.collection("careRequests").document(requestId)
        _ = try await db.runTransaction { transaction, errorPointer in
            guard let snapshot = try? transaction.getDocument(ref) else {
                errorPointer?.pointee = NSError(domain: "CareRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read request."])
                return nil
            }
            guard let data = snapshot.data(),
                  (data["status"] as? String) != "answered" else {
                errorPointer?.pointee = NSError(
                    domain: "CareRequestService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "This request has already been answered by another social worker."]
                )
                return nil
            }
            let update: [String: Any] = [
                "replyText": replyText,
                "status": "answered",
                "repliedAt": FieldValue.serverTimestamp(),
                "repliedBy": uid
            ]
            if (try? transaction.updateData(update, forDocument: ref)) == nil {
                errorPointer?.pointee = NSError(domain: "CareRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update request."])
                return nil
            }
            return nil
        }
    }
}
