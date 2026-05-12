//
//  RootView.swift
//  CareCircle
//

import SwiftUI
import FirebaseAuth

/// Root controller: Auth (CareCircle welcome) when logged out, dashboard when logged in.
struct RootView: View {
    @State private var sessionUser: AppUser?
    @State private var authPath: [AppRoute] = []

    var body: some View {
        Group {
            if sessionUser != nil {
                ContentView(sessionUser: $sessionUser, onLogout: { sessionUser = nil })
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                authFlow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: sessionUser != nil)
        .task {
            await restoreSessionIfNeeded()
        }
    }

    private var authFlow: some View {
        NavigationStack(path: $authPath) {
            WelcomeView {
                authPath.append(.login)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .login:
                    LoginView { appUser in
                        sessionUser = appUser
                    }
                case .caregiverDashboard, .socialWorkerDashboard, .communityDashboard:
                    EmptyView()
                }
            }
        }
    }

    private func restoreSessionIfNeeded() async {
        guard sessionUser == nil,
              let firebaseUser = Auth.auth().currentUser else { return }
        do {
            let appUser = try await UserService.shared.fetchUser(for: firebaseUser)
            await MainActor.run {
                sessionUser = appUser
            }
        } catch {
            await MainActor.run {
                try? Auth.auth().signOut()
            }
        }
    }
}
