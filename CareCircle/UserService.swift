import Foundation
import FirebaseAuth
import FirebaseFirestore

struct AppUser {
    let uid: String
    let email: String
    let role: UserRole
    let name: String
    let caretakerNumber: String?
    let phone: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
}

enum UserServiceError: LocalizedError {
    case missingUserData

    var errorDescription: String? {
        switch self {
        case .missingUserData:
            return "Your profile couldn’t be loaded. Please try again or sign up again."
        }
    }
}

/// Handles Firestore reads/writes for user documents.
final class UserService {
    static let shared = UserService()

    private let db = Firestore.firestore()

    private init() {}

    /// - Parameter name: Display name; defaults to email if empty.
    func createUserDocument(for user: User, role: UserRole, name: String? = nil) async throws -> AppUser {
        let email = user.email ?? ""
        let displayName = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? email
        let docRef = db.collection("users").document(user.uid)

        var data: [String: Any] = [
            "email": email,
            "name": displayName,
            "role": role.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if role == .caregiver {
            data["caretakerNumber"] = Self.generateCaretakerNumber()
        }

        try await docRef.setData(data, merge: true)

        return AppUser(
            uid: user.uid,
            email: email,
            role: role,
            name: displayName,
            caretakerNumber: data["caretakerNumber"] as? String,
            phone: data["phone"] as? String,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            createdAt: Date()
        )
    }

    private static func generateCaretakerNumber() -> String {
        let digits = (0..<6).map { _ in String(Int.random(in: 0...9)) }
        return "CG-" + digits.joined()
    }

    /// Update the current user's name and phone in Firestore (e.g. before accepting a community request).
    func updateCurrentUserProfile(name: String, phone: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let docRef = db.collection("users").document(uid)
        let data: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        try await docRef.setData(data, merge: true)
    }

    /// Save current user's location (called after permission or city geocode).
    func updateUserLocation(latitude: Double, longitude: Double) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let docRef = db.collection("users").document(uid)
        try await docRef.setData([
            "latitude": latitude,
            "longitude": longitude
        ], merge: true)
    }

    func fetchUser(for user: User) async throws -> AppUser {
        let doc = try await db.collection("users").document(user.uid).getDocument()

        guard let data = doc.data(),
              let email = data["email"] as? String,
              let roleString = data["role"] as? String,
              let role = UserRole(rawValue: roleString) else {
            throw UserServiceError.missingUserData
        }

        let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? email
        let caretakerNumber = data["caretakerNumber"] as? String
        let phone = data["phone"] as? String
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        return AppUser(
            uid: user.uid,
            email: email,
            role: role,
            name: name,
            caretakerNumber: caretakerNumber,
            phone: phone,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt
        )
    }

    /// Fetch any user by uid (e.g. to show helper name/phone on accepted community request). Requires read access to that user's document.
    func fetchUser(uid: String) async throws -> AppUser? {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data(),
              let email = data["email"] as? String,
              let roleString = data["role"] as? String,
              let role = UserRole(rawValue: roleString) else {
            return nil
        }
        let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? email
        let caretakerNumber = data["caretakerNumber"] as? String
        let phone = data["phone"] as? String
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        return AppUser(
            uid: uid,
            email: email,
            role: role,
            name: name,
            caretakerNumber: caretakerNumber,
            phone: phone,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt
        )
    }
}

