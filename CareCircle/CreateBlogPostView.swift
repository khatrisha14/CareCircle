import SwiftUI
import FirebaseAuth

// MARK: - Social Worker: Create message (title, content, category)

struct CreateBlogPostView: View {
    let onDismiss: () -> Void
    let onPublished: () -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var category: SupportPostTag = .general
    @State private var isPublishing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                        .textContentType(.none)
                } header: {
                    Text("Message")
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(SupportPostTag.allCases, id: \.self) { tag in
                            Text(tag.label).tag(tag)
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
            .navigationTitle("New Message")
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
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        isPublishing = true
        errorMessage = nil
        Task {
            do {
                guard let firebaseUser = Auth.auth().currentUser,
                      let appUser = try? await UserService.shared.fetchUser(for: firebaseUser) else {
                    await MainActor.run {
                        isPublishing = false
                        errorMessage = "Could not load your profile."
                    }
                    return
                }
                _ = try await SocialPostService.shared.createPost(
                    title: t,
                    content: c,
                    category: category.rawValue,
                    authorName: appUser.name,
                    latitude: appUser.latitude,
                    longitude: appUser.longitude
                )
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
