import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Model for social worker posts (supportPosts collection).
struct SupportPost: Identifiable {
    let id: String
    let title: String
    let body: String
    let tag: String
    let createdAt: Date
    let latitude: Double?
    let longitude: Double?

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let title = data["title"] as? String,
              let body = data["body"] as? String else {
            return nil
        }
        self.id = document.documentID
        self.title = title
        self.body = body
        self.tag = data["tag"] as? String ?? ""
        self.latitude = data["latitude"] as? Double
        self.longitude = data["longitude"] as? Double
        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

/// Fetches and creates support posts. Only social workers may create.
final class SupportPostService {
    static let shared = SupportPostService()
    private let db = Firestore.firestore()

    private init() {}

    /// Fetches support posts within 50km of (userLat, userLng), ordered by createdAt (latest first).
    func fetchSupportPosts(userLat: Double, userLng: Double) async throws -> [SupportPost] {
        let snapshot = try await db.collection("supportPosts")
            .getDocuments()
        let all = snapshot.documents.compactMap { doc -> SupportPost? in
            SupportPost(document: doc)
        }
        let within50km = all.filter { post in
            guard let lat = post.latitude, let lng = post.longitude else { return false }
            return GeoService.distanceInKM(lat1: userLat, lon1: userLng, lat2: lat, lon2: lng) <= 50
        }
        return within50km.sorted { $0.createdAt > $1.createdAt }
    }

    /// Creates a support post with author's location. Call as social worker only (Firestore rules enforce).
    func createPost(title: String, body: String, tag: String, latitude: Double, longitude: Double) async throws {
        let data: [String: Any] = [
            "title": title,
            "body": body,
            "tag": tag,
            "createdAt": FieldValue.serverTimestamp(),
            "authorRole": "socialWorker",
            "latitude": latitude,
            "longitude": longitude
        ]
        _ = try await db.collection("supportPosts").addDocument(data: data)
    }
}
