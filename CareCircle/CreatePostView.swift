import SwiftUI
import FirebaseAuth

// MARK: - Social Worker: Create guidance post for caregivers

struct CreatePostView: View {
    let onDismiss: () -> Void
    let onPublished: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var tag: SupportPostTag = .general
    @State private var isPublishing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)
                } header: {
                    Text("Content")
                }

                Section {
                    Picker("Tag", selection: $tag) {
                        ForEach(SupportPostTag.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Category")
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        publish()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPublishing)
                }
            }
            .overlay {
                if isPublishing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Publishing…")
                        .tint(.white)
                }
            }
        }
    }

    private func publish() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        isPublishing = true
        errorMessage = nil
        Task {
            do {
                guard let firebaseUser = FirebaseAuth.Auth.auth().currentUser,
                      let appUser = try? await UserService.shared.fetchUser(for: firebaseUser),
                      let lat = appUser.latitude,
                      let lng = appUser.longitude else {
                    await MainActor.run {
                        isPublishing = false
                        errorMessage = "Location required to publish. Update your location in settings."
                    }
                    return
                }
                try await SupportPostService.shared.createPost(title: t, body: b, tag: tag.rawValue, latitude: lat, longitude: lng)
                await MainActor.run {
                    isPublishing = false
                    onPublished()
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Tag options for support posts

enum SupportPostTag: String, CaseIterable {
    case burnout = "Burnout"
    case routines = "Routines"
    case emotionalCare = "Emotional Care"
    case general = "General"

    var label: String { rawValue }
}
