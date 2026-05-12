import Foundation
import FirebaseFirestore

/// Social worker message: title, content, category. Firestore: socialPosts (no Storage).
struct SocialPost: Identifiable {
    let id: String
    let title: String
    let content: String
    let category: String
    let createdAt: Date
    let authorId: String
    let authorName: String
    let latitude: Double?
    let longitude: Double?

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let authorId = data["authorId"] as? String ?? data["socialWorkerId"] as? String,
              let authorName = data["authorName"] as? String else {
            return nil
        }
        self.id = document.documentID
        self.title = data["title"] as? String ?? ""
        self.content = data["content"] as? String ?? data["text"] as? String ?? ""
        self.category = data["category"] as? String ?? ""
        self.authorId = authorId
        self.authorName = authorName
        self.latitude = data["latitude"] as? Double
        self.longitude = data["longitude"] as? Double
        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}
