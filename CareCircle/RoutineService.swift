import Foundation
import FirebaseAuth
import FirebaseFirestore

struct Routine: Identifiable, Codable {
    let id: String
    let caregiverId: String
    let title: String
    let note: String
    let symbol: String
    let createdAt: Date
    let reminderEnabled: Bool
    let reminderTime: Date?
    /// Filename in Documents/routines/ (e.g. "UUID.jpg"). Stored in Firestore as string.
    let imagePath: String?

    init(
        id: String = UUID().uuidString,
        caregiverId: String,
        title: String,
        note: String,
        symbol: String = "checkmark.circle.fill",
        createdAt: Date = Date(),
        reminderEnabled: Bool = false,
        reminderTime: Date? = nil,
        imagePath: String? = nil
    ) {
        self.id = id
        self.caregiverId = caregiverId
        self.title = title
        self.note = note
        self.symbol = symbol
        self.createdAt = createdAt
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.imagePath = imagePath
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let caregiverId = data["caregiverId"] as? String,
              let title = data["title"] as? String,
              let note = data["note"] as? String else {
            return nil
        }

        let symbol = data["symbol"] as? String ?? "checkmark.circle.fill"
        let imagePath = data["imagePath"] as? String

        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else {
            createdAt = Date()
        }

        let reminderEnabled = data["reminderEnabled"] as? Bool ?? false
        var reminderTime: Date?
        if let ts = data["reminderTime"] as? Timestamp {
            reminderTime = ts.dateValue()
        }

        self.id = document.documentID
        self.caregiverId = caregiverId
        self.title = title
        self.note = note
        self.symbol = symbol
        self.createdAt = createdAt
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.imagePath = imagePath
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "caregiverId": caregiverId,
            "title": title,
            "note": note,
            "symbol": symbol,
            "createdAt": FieldValue.serverTimestamp(),
            "reminderEnabled": reminderEnabled
        ]
        if let path = imagePath, !path.isEmpty {
            dict["imagePath"] = path
        }
        if let time = reminderTime {
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: time)
            var ref = DateComponents()
            ref.year = 2000
            ref.month = 1
            ref.day = 1
            ref.hour = comps.hour
            ref.minute = comps.minute
            if let refDate = cal.date(from: ref) {
                dict["reminderTime"] = Timestamp(date: refDate)
            }
        }
        return dict
    }
}

final class RoutineService {
    static let shared = RoutineService()

    private let db = Firestore.firestore()

    private init() {}

    func createRoutine(
        title: String,
        note: String,
        symbol: String = "checkmark.circle.fill",
        reminderEnabled: Bool = false,
        reminderTime: Date? = nil,
        imagePath: String? = nil
    ) async throws -> Routine {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "RoutineService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }

        let routine = Routine(
            caregiverId: uid,
            title: title,
            note: note,
            symbol: symbol,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderTime,
            imagePath: imagePath
        )

        let docRef = db.collection("routines").document(routine.id)
        try await docRef.setData(routine.asDictionary)

        return routine
    }

    func updateRoutine(_ routine: Routine) async throws {
        guard Auth.auth().currentUser?.uid == routine.caregiverId else {
            throw NSError(domain: "RoutineService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only update your own routines."])
        }
        try await db.collection("routines").document(routine.id).setData(routine.asDictionary)
    }

    func fetchRoutinesForCurrentCaregiver() async throws -> [Routine] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "RoutineService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }

        let query = db.collection("routines")
            .whereField("caregiverId", isEqualTo: uid)

        let snapshot = try await query.getDocuments()
        let routines = snapshot.documents.compactMap { Routine(document: $0) }
        return routines.sorted { $0.createdAt < $1.createdAt }
    }

    func deleteRoutine(_ routine: Routine) async throws {
        guard Auth.auth().currentUser?.uid == routine.caregiverId else {
            throw NSError(domain: "RoutineService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only delete your own routines."])
        }
        try await db.collection("routines").document(routine.id).delete()
    }
}

