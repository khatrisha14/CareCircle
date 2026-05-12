import SwiftUI
import FirebaseAuth

// MARK: - Social Connect (caregiver: messages from social workers + own requests)

struct SocialConnectView: View {
    @State private var messages: [SocialPost] = []
    @State private var requests: [CareRequest] = []
    @State private var isLoadingMessages = true
    @State private var isLoadingRequests = true
    @State private var errorMessage: String?
    @State private var selectedRequest: CareRequest?

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    messagesSection
                    requestsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Social Connect")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadAll()
                await MainActor.run {
                    let answeredIds = requests.filter(\.isAnswered).map(\.id)
                    if !answeredIds.isEmpty {
                        UnseenRepliesManager.shared.markAsSeen(requestIds: answeredIds)
                    }
                }
            }
        }
        .refreshable {
            await loadAll()
        }
        .sheet(item: $selectedRequest) { request in
            RequestDetailView(request: request, onDismiss: { selectedRequest = nil })
        }
    }

    private func loadAll() async {
        errorMessage = nil
        async let messagesTask: () = loadMessages()
        async let requestsTask: () = loadRequests()
        _ = await (messagesTask, requestsTask)
    }

    private func loadMessages() async {
        isLoadingMessages = true
        defer { isLoadingMessages = false }
        do {
            messages = try await SocialPostService.shared.fetchAllPosts()
        } catch {
            errorMessage = error.localizedDescription
            messages = []
        }
    }

    private func loadRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }
        do {
            requests = try await CareRequestService.shared.fetchCaregiverRequests()
        } catch {
            errorMessage = error.localizedDescription
            requests = []
        }
    }

    // MARK: - Section: Messages from Social Workers

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Messages from Social Workers")
                .font(AppTextStyle.sectionTitle)
                .foregroundStyle(.white)

            if isLoadingMessages {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if messages.isEmpty {
                Text("No messages yet.")
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        SocialPostCard(post: message)
                    }
                }
            }
        }
    }

    // MARK: - Section: Your requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your requests")
                .font(AppTextStyle.sectionTitle)
                .foregroundStyle(.white)

            if let err = errorMessage {
                Text(err)
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.red)
                    .padding(.vertical, 8)
            }
            if isLoadingRequests {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if requests.isEmpty && errorMessage == nil {
                Text("No support requests yet.")
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if !requests.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(requests) { request in
                            CareRequestCard(
                                request: request,
                                onTap: request.isAnswered ? { selectedRequest = request } : nil
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Social worker message card – read-only for caregivers

private struct SocialPostCard: View {
    let post: SocialPost

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    private var authorLabel: String {
        post.authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Social Worker" : post.authorName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !post.category.isEmpty {
                Text(post.category)
                    .font(AppTextStyle.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.cardSecondary)
                    )
                    .padding(.bottom, 10)
            }

            if !post.title.isEmpty {
                Text(post.title)
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 8)
            }

            Text(post.content)
                .font(AppTextStyle.body)
                .foregroundStyle(.primary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.primaryGreen.opacity(0.9))
                Text(authorLabel)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Text(Self.dateFormatter.string(from: post.createdAt))
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Support post card (read-only)

private struct SupportPostCard: View {
    let post: SupportPost

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !post.tag.isEmpty {
                Text(post.tag)
                    .font(AppTextStyle.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.cardSecondary)
                    )
            }
            Text(post.title)
                .font(AppTextStyle.sectionTitle)
            Text(post.body)
                .font(AppTextStyle.secondary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Social Worker")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(Self.dateFormatter.string(from: post.createdAt))
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
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

// MARK: - Care request card (tappable if answered)

private struct CareRequestCard: View {
    let request: CareRequest
    var onTap: (() -> Void)?

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    private var questionPreview: String {
        if !request.questionText.isEmpty {
            return request.questionText
        }
        return "Support request"
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Self.dateFormatter.string(from: request.date))
                        .font(AppTextStyle.secondary.weight(.medium))
                    Text(questionPreview)
                        .font(AppTextStyle.secondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    statusBadge
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if request.isAnswered {
                    Image(systemName: "chevron.right")
                        .font(AppTextStyle.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    private var statusBadge: some View {
        Text(request.status == "answered" ? "Answered" : "Pending")
            .font(AppTextStyle.caption.weight(.medium))
            .foregroundStyle(request.status == "answered" ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(request.status == "answered" ? AppTheme.primaryGreen : Color(.tertiarySystemFill))
            )
    }
}

// MARK: - Request detail: question only + response (no full report)

struct RequestDetailView: View {
    let request: CareRequest
    let onDismiss: () -> Void

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        questionSection
                        if request.isAnswered, let reply = request.replyText, !reply.isEmpty {
                            responseSection(reply: reply)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Request details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your question")
                .font(AppTextStyle.sectionTitle)
            if !request.questionText.isEmpty {
                Text(request.questionText)
                    .font(AppTextStyle.body)
            } else {
                Text("Support request from \(Self.dateFormatter.string(from: request.date))")
                    .font(AppTextStyle.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
    }

    private func responseSection(reply: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Response from Social Worker")
                .font(AppTextStyle.sectionTitle)
            Text(reply)
                .font(AppTextStyle.body)
            if let at = request.repliedAt {
                Text(Self.dateFormatter.string(from: at))
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
    }
}
