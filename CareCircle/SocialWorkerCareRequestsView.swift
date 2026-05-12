import SwiftUI
import FirebaseAuth

// MARK: - Social Worker: My Messages tab – list, delete, create

struct SocialWorkerMyPostsView: View {
    var onLogout: () -> Void
    @State private var posts: [SocialPost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreatePost = false
    @State private var showPublishedBanner = false

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()
            Group {
                if isLoading {
                    ProgressView("Loading…")
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await load() }
                        }
                        .buttonStyle(PrimaryGreenButtonStyle())
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if posts.isEmpty {
                    Text("No messages yet.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(posts) { post in
                                SocialWorkerMyPostCard(
                                    post: post,
                                    onDelete: { deletePost(post) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .navigationTitle("My Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Log out") {
                    try? Auth.auth().signOut()
                    onLogout()
                }
                .foregroundStyle(AppTheme.primaryGreen)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New Message") {
                    showCreatePost = true
                }
                .foregroundStyle(AppTheme.primaryGreen)
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreateBlogPostView(
                onDismiss: { showCreatePost = false },
                onPublished: {
                    showCreatePost = false
                    showPublishedBanner = true
                    Task { await load() }
                }
            )
        }
        .overlay {
            if showPublishedBanner {
                PublishedConfirmationBanner(onDismiss: { showPublishedBanner = false })
            }
        }
        .onChange(of: showPublishedBanner) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await MainActor.run { showPublishedBanner = false }
                }
            }
        }
        .onAppear {
            Task { await load() }
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            posts = try await SocialPostService.shared.fetchMyPosts()
        } catch {
            errorMessage = error.localizedDescription
            posts = []
        }
    }

    private func deletePost(_ post: SocialPost) {
        Task {
            do {
                try await SocialPostService.shared.deletePost(post)
                await MainActor.run {
                    posts.removeAll { $0.id == post.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - My Message card (title, category, content preview, date, delete)

private struct SocialWorkerMyPostCard: View {
    let post: SocialPost
    let onDelete: () -> Void

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    private var contentPreview: String {
        let trimmed = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        return trimmed.count > 120 ? String(trimmed.prefix(120)) + "…" : trimmed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if !post.title.isEmpty {
                    Text(post.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                if !post.category.isEmpty {
                    Text(post.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(contentPreview)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(Self.dateFormatter.string(from: post.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete message")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Social Worker: Care Requests dashboard (pending only, oldest first)

struct SocialWorkerCareRequestsView: View {
    var onLogout: () -> Void
    @State private var requests: [CareRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRequest: CareRequest?
    @State private var showCreatePost = false
    @State private var showPublishedConfirmation = false

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()
            Group {
                if isLoading {
                    ProgressView("Loading requests…")
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await load() }
                        }
                        .buttonStyle(PrimaryGreenButtonStyle())
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if requests.isEmpty {
                    Text("No pending requests.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(requests) { request in
                                NavigationLink(value: request) {
                                    SocialWorkerRequestCard(request: request)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .navigationTitle("Care Requests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Log out") {
                    try? Auth.auth().signOut()
                    onLogout()
                }
                .foregroundStyle(AppTheme.primaryGreen)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Create Post") {
                    showCreatePost = true
                }
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(
                onDismiss: { showCreatePost = false },
                onPublished: {
                    showCreatePost = false
                    showPublishedConfirmation = true
                }
            )
        }
        .overlay {
            if showPublishedConfirmation {
                PublishedConfirmationBanner(onDismiss: { showPublishedConfirmation = false })
            }
        }
        .onChange(of: showPublishedConfirmation) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await MainActor.run { showPublishedConfirmation = false }
                }
            }
        }
        .onAppear {
            Task { await load() }
        }
        .refreshable {
            await load()
        }
        .navigationDestination(for: CareRequest.self) { request in
            SocialWorkerRequestDetailView(request: request) {
                Task { await load() }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            requests = try await CareRequestService.shared.fetchPendingCareRequests()
        } catch {
            errorMessage = error.localizedDescription
            requests = []
        }
    }
}

// MARK: - Request card (list)

private struct SocialWorkerRequestCard: View {
    let request: CareRequest

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    private var shortNote: String {
        if !request.questionText.isEmpty { return request.questionText }
        if !request.freeNote.isEmpty { return request.freeNote }
        if !request.unexpectedNote.isEmpty { return request.unexpectedNote }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.dateFormatter.string(from: request.date))
                .font(.subheadline.weight(.semibold))
            Text("\(request.intensity) intensity · \(request.routinesCompletedCount) of \(request.routinesTotalCount) routines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !request.supportNeeded.isEmpty {
                Text("Support: \(request.supportNeeded)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(shortNote)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Request detail + response (social worker)

struct SocialWorkerRequestDetailView: View {
    let request: CareRequest
    let onResponseSent: () -> Void

    @State private var replyText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                requestDetailsSection
                responseSection
            }
            .padding(20)
        }
        .navigationTitle("Request details")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .overlay {
            if isSending {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Sending…")
                    .tint(.white)
            }
        }
    }

    private var requestDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Request details")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                detailRow("Date", Self.dateFormatter.string(from: request.date))
                detailRow("Intensity", request.intensity)
                if !request.strainAreas.isEmpty {
                    detailRow("Strain areas", request.strainAreas.joined(separator: ", "))
                }
                if !request.routineDisruption.isEmpty {
                    detailRow("Routine disruption", request.routineDisruption)
                }
                if !request.unexpectedEvent.isEmpty {
                    detailRow("Unexpected event", request.unexpectedEvent)
                }
                if !request.unexpectedNote.isEmpty {
                    detailRow("Details", request.unexpectedNote)
                }
                if !request.supportNeeded.isEmpty {
                    detailRow("Support needed", request.supportNeeded)
                }
                if !request.questionText.isEmpty {
                    detailRow("Caregiver question", request.questionText)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your response")
                .font(.headline)
            ZStack(alignment: .topLeading) {
                if replyText.isEmpty {
                    Text("Write your response")
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $replyText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .scrollContentBackground(.hidden)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )

            Button {
                sendResponse()
            } label: {
                Text("Send response")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryGreenButtonStyle())
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
    }

    private func sendResponse() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        errorMessage = nil
        Task {
            do {
                try await CareRequestService.shared.respondToCareRequest(requestId: request.id, replyText: text)
                await MainActor.run {
                    isSending = false
                    onResponseSent()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Subtle "Post published" confirmation

private struct PublishedConfirmationBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                Text("Post published")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.primaryGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .onTapGesture { onDismiss() }
            Spacer()
        }
    }
}

// MARK: - CareRequest Hashable for navigationDestination

extension CareRequest: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    public static func == (lhs: CareRequest, rhs: CareRequest) -> Bool {
        lhs.id == rhs.id
    }
}
