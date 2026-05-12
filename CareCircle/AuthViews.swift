import SwiftUI
import FirebaseAuth

// MARK: - Design system

/// Shared green gradient background for auth (mint top → dark forest bottom).
struct AuthBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            AppTheme.screenGradient
        }
        .ignoresSafeArea()
        .overlay(
            content()
                .padding(.horizontal, 16)
        )
    }
}

/// Primary button – dark green, rounded (auth + app).
struct PrimaryAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTextStyle.button)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.primaryGreenLight : AppTheme.primaryGreen)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
    }
}

/// Secondary text button (mode toggles) – always visible, green on theme.
struct SecondaryAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? AppTheme.primaryGreen.opacity(0.8) : AppTheme.primaryGreen)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
    }
}

/// Card surface for auth forms – material + white/green blend (no liquid glass).
struct AuthCardBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.liquidGlassGreenTint.opacity(0.5),
                            AppTheme.liquidGlassTint.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

// MARK: - User role

enum UserRole: String, CaseIterable, Identifiable {
    case caregiver
    case socialWorker
    case community

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caregiver: return "Caregiver"
        case .socialWorker: return "Social Worker"
        case .community: return "Community Member"
        }
    }

    var description: String {
        switch self {
        case .caregiver:
            return "Support loved ones with organized, gentle care."
        case .socialWorker:
            return "Coordinate resources and stay connected with families."
        case .community:
            return "Connect with local care resources and support."
        }
    }

    /// Only caregivers have a generated caretakerNumber.
    var usesCaretakerNumber: Bool { self == .caregiver }
}

// MARK: - Welcome

struct WelcomeView: View {
    let onGetStarted: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            WelcomeBackgroundCircles()

            Group {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 40) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                Spacer(minLength: 40)
                                WelcomeContentCard(appeared: appeared, onGetStarted: onGetStarted)
                                    .padding(.horizontal, 20)
                                Spacer(minLength: 44)
                            }
                        }
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 40)
                            WelcomeContentCard(appeared: appeared, onGetStarted: onGetStarted)
                                .padding(.horizontal, 20)
                            Spacer(minLength: 44)
                        }
                    }
                }
            }
            .padding(.horizontal, 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                appeared = true
            }
        }
    }
}

// One card: logo, title, tagline, CTA — liquid glass with white + green blend
private struct WelcomeContentCard: View {
    let appeared: Bool
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            CareCircleLogoView()
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)

            Text("CareCircle")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(AppTheme.primaryGreen)
                .multilineTextAlignment(.center)
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)

            Text("A calmer way to coordinate care and stay connected.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.primaryGreen.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 16)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Button(action: onGetStarted) {
                    HStack(spacing: 10) {
                        Text("Get started")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryAuthButtonStyle())
                .accessibilityLabel("Get started with CareCircle")

                Text("You can adjust your details at any time.")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppTheme.primaryGreen.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .modifier(WelcomeCardGlassModifier())
    }
}

// Welcome card: iOS 26+ native .glassEffect(), else material + white/green blend.
private struct WelcomeCardGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(AppTheme.primaryGreen.opacity(0.25)), in: .rect(cornerRadius: 28))
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        } else {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.liquidGlassGreenTint.opacity(0.7),
                                        Color.white.opacity(0.55),
                                        AppTheme.liquidGlassGreenTint.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
    }
}

// Soft circular shapes in background (brand motif + depth)
private struct WelcomeBackgroundCircles: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 2)
                .offset(x: -80, y: -180)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 25)
                .offset(x: 100, y: 120)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 180, height: 180)
                .blur(radius: 20)
                .offset(x: -60, y: 320)
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

// Logo: double ring + heart (care circle); dark green on light card
private struct CareCircleLogoView: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AppTheme.primaryGreen.opacity(0.4), lineWidth: 2)
                .frame(width: 72, height: 72)
            Circle()
                .strokeBorder(AppTheme.primaryGreen.opacity(0.55), lineWidth: 1.5)
                .frame(width: 56, height: 56)
            Image(systemName: "heart.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.primaryGreen)
        }
        .frame(width: 88, height: 88)
    }
}

// MARK: - Login

struct LoginView: View {
    private enum AuthMode {
        case login
        case signUp
    }

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var mode: AuthMode = .login
    @State private var selectedRole: UserRole = .caregiver

    let onAuthenticated: (AppUser) -> Void

    var body: some View {
        AuthBackground {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode == .login ? "Welcome back" : "Create your account")
                        .font(AppTextStyle.sectionTitle)
                        .foregroundStyle(.white)

                    Text(mode == .login
                         ? "Sign in to continue caring with your circle."
                         : "Set up a new CareCircle account with your email and a secure password.")
                        .font(AppTextStyle.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                formWithBackground
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var formWithBackground: some View {
        let form = Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.body)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .font(.body)

                if mode == .signUp {
                    Picker("Role", selection: $selectedRole) {
                        Text(UserRole.caregiver.title).tag(UserRole.caregiver)
                        Text(UserRole.socialWorker.title).tag(UserRole.socialWorker)
                        Text(UserRole.community.title).tag(UserRole.community)
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Your role")
                }
            } header: {
                Text("Sign in")
            }

            Section {
                Button {
                    Task { await handleContinueTapped() }
                } label: {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().progressViewStyle(.circular)
                            Text(mode == .login ? "Logging in…" : "Creating account…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(mode == .login ? "Log In" : "Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryAuthButtonStyle())
                .listRowInsets(EdgeInsets())
                .disabled(isLoading)

                Button { toggleMode() } label: {
                    Text(mode == .login
                         ? "New here? Create an account"
                         : "Already have an account? Log in")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(SecondaryAuthButtonStyle())

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .accessibilityLabel("Authentication error: \(errorMessage)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            AuthCardBackground()
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        )

        form
    }

    // MARK: - Actions

    private func handleContinueTapped() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let appUser: AppUser

            switch mode {
            case .login:
                let firebaseUser = try await AuthService.shared.signIn(email: email, password: password)
                do {
                    appUser = try await UserService.shared.fetchUser(for: firebaseUser)
                } catch is UserServiceError {
                    // No user doc yet (e.g. account created before we saved profile). Create one with default role so login succeeds.
                    appUser = try await UserService.shared.createUserDocument(for: firebaseUser, role: .caregiver)
                }

            case .signUp:
                let firebaseUser = try await AuthService.shared.signUp(email: email, password: password)
                appUser = try await UserService.shared.createUserDocument(for: firebaseUser, role: selectedRole)
            }

            await MainActor.run {
                isLoading = false
                onAuthenticated(appUser)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleMode() {
        mode = (mode == .login) ? .signUp : .login
        errorMessage = nil
    }
}

// MARK: - Role Selection

struct RoleSelectionView: View {
    @State private var selectedRole: UserRole?

    var body: some View {
        AuthBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose your role")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("This helps us tailor CareCircle to how you support others. You can always adjust this later.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineSpacing(2)
                    }

                    VStack(spacing: 16) {
                        roleButton(for: .caregiver)
                        roleButton(for: .socialWorker)
                        roleButton(for: .community)
                    }
                    .padding(.top, 4)

                    if let selectedRole {
                        Text("Selected: \(selectedRole.title)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Your role")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func roleButton(for role: UserRole) -> some View {
        Button {
            selectedRole = role
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(role.title)
                    .font(.headline.weight(.semibold))

                Text(role.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    // Slightly tinted surface within the overall card system
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.98),
                                    AppTheme.mintGreen.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            selectedRole == role
                            ? AppTheme.primaryGreen
                            : Color.black.opacity(0.06),
                            lineWidth: selectedRole == role ? 1.4 : 1
                        )
                }
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(role.title). \(role.description)")
    }
}

#Preview("Welcome") {
    NavigationStack {
        WelcomeView(onGetStarted: {})
    }
}

#Preview("Login") {
    NavigationStack {
        LoginView { _ in }
    }
}

#Preview("Role Selection") {
    NavigationStack {
        RoleSelectionView()
    }
}

