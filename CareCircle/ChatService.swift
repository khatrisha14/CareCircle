import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Service

@MainActor
final class ChatService: ObservableObject {
    static let shared = ChatService()

    @Published private(set) var messages: [Message] = []
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private var messagesListener: ListenerRegistration?

    private init() {}

    func startListeningMessages(requestId: String) {
        stopMessagesListener()
        messagesListener = db.collection("messages")
            .whereField("requestId", isEqualTo: requestId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    self?.errorMessage = nil
                    let list = (snapshot?.documents ?? []).compactMap { doc -> Message? in
                        Message.from(doc.data(), documentId: doc.documentID)
                    }
                    self?.messages = list.sorted { $0.createdAt < $1.createdAt }
                }
            }
    }

    func stopMessagesListener() {
        messagesListener?.remove()
        messagesListener = nil
    }

    func sendMessage(requestId: String, text: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let ref = db.collection("messages").document()
        let data: [String: Any] = [
            "requestId": requestId,
            "senderId": uid,
            "text": trimmed,
            "type": Message.MessageType.text.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await ref.setData(data)
    }

    /// System message (e.g. "Community member X accepted this request."). senderId = "system".
    func sendSystemMessage(requestId: String, text: String) async throws {
        let ref = db.collection("messages").document()
        let data: [String: Any] = [
            "requestId": requestId,
            "senderId": "system",
            "text": text,
            "type": Message.MessageType.system.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await ref.setData(data)
    }

    /// One-time location share. Creates a message with type "location" and lat/lng.
    func sendLocationMessage(requestId: String, latitude: Double, longitude: Double) async throws {
        guard Auth.auth().currentUser?.uid != nil else { return }
        let uid = Auth.auth().currentUser!.uid
        let ref = db.collection("messages").document()
        let data: [String: Any] = [
            "requestId": requestId,
            "senderId": uid,
            "type": Message.MessageType.location.rawValue,
            "latitude": latitude,
            "longitude": longitude,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await ref.setData(data)
    }
}
