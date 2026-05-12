import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Service

@MainActor
final class CommunityService: ObservableObject {
    static let shared = CommunityService()

    @Published private(set) var caregiverRequests: [CommunityRequest] = []
    @Published private(set) var openRequests: [CommunityRequest] = []
    @Published private(set) var acceptedByMeRequests: [CommunityRequest] = []
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private var caregiverListener: ListenerRegistration?
    private var openListener: ListenerRegistration?
    private var acceptedByMeListener: ListenerRegistration?

    private init() {}

    // MARK: - Listeners (real-time)

    func startListeningCaregiverRequests() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        stopCaregiverListener()
        caregiverListener = db.collection("communityRequests")
            .whereField("caregiverId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    self?.errorMessage = nil
                    let list = (snapshot?.documents ?? []).compactMap { doc -> CommunityRequest? in
                        CommunityRequest.from(doc.data(), documentId: doc.documentID)
                    }
                    self?.caregiverRequests = list.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    /// Pass user's location for 50km filtering. Fetches open requests then filters by Haversine <= 50km.
    func startListeningOpenRequests(userLat: Double, userLng: Double) {
        stopOpenListener()
        openListener = db.collection("communityRequests")
            .whereField("status", isEqualTo: CommunityRequest.Status.open.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    self?.errorMessage = nil
                    let list = (snapshot?.documents ?? []).compactMap { doc -> CommunityRequest? in
                        CommunityRequest.from(doc.data(), documentId: doc.documentID)
                    }
                    let within50km = list.filter { req in
                        guard let lat = req.latitude, let lng = req.longitude else { return false }
                        return GeoService.distanceInKM(lat1: userLat, lon1: userLng, lat2: lat, lon2: lng) <= 50
                    }
                    self?.openRequests = within50km.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    /// Community member: requests they have accepted (status accepted or completed).
    func startListeningAcceptedByMe() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        stopAcceptedByMeListener()
        acceptedByMeListener = db.collection("communityRequests")
            .whereField("acceptedBy", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    self?.errorMessage = nil
                    let list = (snapshot?.documents ?? []).compactMap { doc -> CommunityRequest? in
                        CommunityRequest.from(doc.data(), documentId: doc.documentID)
                    }
                    self?.acceptedByMeRequests = list.filter { $0.status == .accepted }.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    func stopCaregiverListener() {
        caregiverListener?.remove()
        caregiverListener = nil
    }

    func stopOpenListener() {
        openListener?.remove()
        openListener = nil
    }

    func stopAcceptedByMeListener() {
        acceptedByMeListener?.remove()
        acceptedByMeListener = nil
    }

    func stopAllListeners() {
        stopCaregiverListener()
        stopOpenListener()
        stopAcceptedByMeListener()
    }

    // MARK: - Writes

    func createRequest(title: String, description: String, caretakerNumber: String, latitude: Double, longitude: Double) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("communityRequests").document()
        let data: [String: Any] = [
            "caregiverId": uid,
            "caretakerNumber": caretakerNumber,
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "createdAt": FieldValue.serverTimestamp(),
            "status": CommunityRequest.Status.open.rawValue,
            "latitude": latitude,
            "longitude": longitude
        ]
        try await ref.setData(data)
    }

    /// Accept request and set helper details on the document. Used by community member.
    func acceptRequest(requestId: String, helperName: String, helperPhone: String, helperTime: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("communityRequests").document(requestId)
        let name = helperName.trimmingCharacters(in: .whitespacesAndNewlines)
        try await ref.updateData([
            "status": CommunityRequest.Status.accepted.rawValue,
            "acceptedBy": uid,
            "helperName": name,
            "helperPhone": helperPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            "helperTime": helperTime.trimmingCharacters(in: .whitespacesAndNewlines)
        ])
        try await ChatService.shared.sendSystemMessage(requestId: requestId, text: "Community member \(name.isEmpty ? "someone" : name) accepted this request.")
    }

    /// Caregiver or accepted community member can mark request completed.
    func markCompleted(requestId: String) async throws {
        let ref = db.collection("communityRequests").document(requestId)
        try await ref.updateData([
            "status": CommunityRequest.Status.completed.rawValue
        ])
        try await ChatService.shared.sendSystemMessage(requestId: requestId, text: "This request has been marked completed.")
    }

    /// Fetch user document for display. Use request.helperName/helperPhone/helperTime when available instead.
    func fetchUserDetails(userId: String) async throws -> AppUser? {
        try await UserService.shared.fetchUser(uid: userId)
    }
}
