import Foundation
import FirebaseAuth

/// Simple wrapper around Firebase Authentication for the email/password flow.
final class AuthService {
    static let shared = AuthService()

    private init() {}

    /// Signs in an existing user with email and password.
    @discardableResult
    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    /// Creates a new user account with email and password.
    @discardableResult
    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }
}

