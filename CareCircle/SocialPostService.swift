import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Creates, fetches, and deletes social worker messages (title, content, category). Firestore only; no Storage.
final class SocialPostService {
    static let shared = SocialPostService()
    private let db = Firestore.firestore()

    private init() {}

    /// Create message (title, content, category) and save to Firestore.
    func createPost(title: String, content: String, category: String, authorName: String, latitude: Double?, longitude: Double?) async throws -> SocialPost {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "SocialPostService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }

        let ref = db.collection("socialPosts").document()
        var data: [String: Any] = [
            "title": title,
            "content": content,
            "category": category,
            "createdAt": FieldValue.serverTimestamp(),
            "authorId": uid,
            "authorName": authorName,
            "socialWorkerId": uid
        ]
        if let lat = latitude { data["latitude"] = lat }
        if let lng = longitude { data["longitude"] = lng }

        try await ref.setData(data)

        let snapshot = try await ref.getDocument()
        guard let post = SocialPost(document: snapshot) else {
            throw NSError(domain: "SocialPostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read created post."])
        }
        return post
    }

    /// Fetch messages by current user (social worker). For "My Messages" tab.
    func fetchMyPosts() async throws -> [SocialPost] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "SocialPostService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
        let snapshot = try await db.collection("socialPosts")
            .whereField("socialWorkerId", isEqualTo: uid)
            .getDocuments()
        let list = snapshot.documents.compactMap { SocialPost(document: $0) }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    /// Fetch all messages for caregivers (read-only). Ordered by createdAt desc.
    func fetchAllPosts() async throws -> [SocialPost] {
        let snapshot = try await db.collection("socialPosts")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { SocialPost(document: $0) }
    }

    /// Delete Firestore document. Call as message owner (rules enforce via socialWorkerId).
    func deletePost(_ post: SocialPost) async throws {
        let ref = db.collection("socialPosts").document(post.id)
        try await ref.delete()
    }
}
