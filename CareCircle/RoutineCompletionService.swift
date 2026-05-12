import Foundation
import FirebaseAuth
import FirebaseFirestore

struct RoutineCompletion: Identifiable {
    let id: String
    let caregiverId: String
    let routineId: String
    let date: String
    let isCompleted: Bool

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let caregiverId = data["caregiverId"] as? String,
              let routineId = data["routineId"] as? String,
              let date = data["date"] as? String,
              let isCompleted = data["isCompleted"] as? Bool else {
            return nil
        }
        self.id = document.documentID
        self.caregiverId = caregiverId
        self.routineId = routineId
        self.date = date
        self.isCompleted = isCompleted
    }

    static func documentId(caregiverId: String, date: String, routineId: String) -> String {
        "\(caregiverId)_\(date)_\(routineId)"
    }
}

final class RoutineCompletionService {
    static let shared = RoutineCompletionService()

    private let db = Firestore.firestore()

    private init() {}

    static var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    /// Fetches today's completions for the current caregiver.
    func fetchCompletionsForToday() async throws -> [RoutineCompletion] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "RoutineCompletionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
        let date = Self.todayDateString
        let snapshot = try await db.collection("routineCompletions")
            .whereField("caregiverId", isEqualTo: uid)
            .getDocuments()
        let all = snapshot.documents.compactMap { RoutineCompletion(document: $0) }
        return all.filter { $0.date == date }
    }

    /// Creates or updates today's completion for a routine. One write; document ID is deterministic.
    func setCompletion(routineId: String, isCompleted: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "RoutineCompletionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
        let date = Self.todayDateString
        let docId = RoutineCompletion.documentId(caregiverId: uid, date: date, routineId: routineId)
        let ref = db.collection("routineCompletions").document(docId)
        try await ref.setData([
            "caregiverId": uid,
            "routineId": routineId,
            "date": date,
            "isCompleted": isCompleted
        ], merge: true)
    }
}
