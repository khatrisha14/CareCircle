import SwiftUI
import FirebaseAuth

// MARK: - Caregiver: Community Access

struct CommunityAccessView: View {
    @StateObject private var service = CommunityService.shared
    @State private var showPostSheet = false
    @State private var caretakerNumber: String = ""
    @State private var userLat: Double?
    @State private var userLng: Double?
    @State private var postError: String?
    @State private var chatRequest: CommunityRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Community Access")
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.white)

                Button {
                    showPostSheet = true
                } label: {
                    Text("Post Help Request")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryGreenButtonStyle())

                if let msg = service.errorMessage {
                    Text(msg)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.red)
                }

                let openList = service.caregiverRequests.filter { $0.status == .open }
                let acceptedList = service.caregiverRequests.filter { $0.status == .accepted }
                let completedList = service.caregiverRequests.filter { $0.status == .completed }

                if !openList.isEmpty {
                    sectionHeader("Open")
                    ForEach(openList) { request in
                        CaregiverRequestCard(request: request, onOpenChat: { chatRequest = request })
                    }
                }

                if !acceptedList.isEmpty {
                    sectionHeader("Accepted")
                    ForEach(acceptedList) { request in
                        CaregiverRequestCard(request: request, onOpenChat: { chatRequest = request })
                    }
                }

                if !completedList.isEmpty {
                    sectionHeader("Completed")
                    ForEach(completedList) { request in
                        CaregiverRequestCard(request: request, onOpenChat: nil)
                    }
                }

                if service.caregiverRequests.isEmpty {
                    Text("No help requests yet. Tap \"Post Help Request\" to create one.")
                        .font(AppTextStyle.secondary)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .task {
            service.startListeningCaregiverRequests()
            await loadCaregiverData()
        }
        .onDisappear {
            service.stopCaregiverListener()
        }
        .sheet(isPresented: $showPostSheet) {
            PostCommunityRequestSheet(
                caretakerNumber: caretakerNumber,
                latitude: userLat,
                longitude: userLng,
                postError: $postError,
                onPost: {
                    showPostSheet = false
                    postError = nil
                },
                onCancel: {
                    showPostSheet = false
                    postError = nil
                }
            )
        }
        .sheet(item: $chatRequest) { request in
            CommunityChatView(request: request)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTextStyle.sectionTitle)
            .foregroundStyle(.white)
    }

    private func loadCaregiverData() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        if let appUser = try? await UserService.shared.fetchUser(for: firebaseUser) {
            await MainActor.run {
                caretakerNumber = appUser.caretakerNumber ?? ""
                userLat = appUser.latitude
                userLng = appUser.longitude
            }
        }
    }
}

private struct CaregiverRequestCard: View {
    let request: CommunityRequest
    var onOpenChat: (() -> Void)?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(request.title)
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.primary)
                Text(request.description)
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.secondary)

                if request.status == .accepted {
                    helperInfoCard
                    if onOpenChat != nil {
                        Button {
                            onOpenChat?()
                        } label: {
                            Text("Open Chat")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryGreenButtonStyle())
                    }
                }

                if request.status == .completed {
                    Text("Completed")
                        .font(AppTextStyle.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var helperInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Community Member Ready to Help")
                .font(AppTextStyle.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryGreen)

            if let name = request.helperName, !name.isEmpty {
                Text(name)
                    .font(AppTextStyle.secondary.weight(.medium))
                    .foregroundStyle(.primary)
            }
            if let phone = request.helperPhone, !phone.isEmpty {
                Text(phone)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
            }
            if let time = request.helperTime, !time.isEmpty {
                Text("When: \(time)")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.primaryGreen.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.primaryGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Chat (caregiver + community)

struct CommunityChatView: View {
    let request: CommunityRequest
    @StateObject private var chatService = ChatService.shared
    @State private var inputText = ""
    @State private var isSending = false
    @State private var isSharingLocation = false
    @State private var shareLocationError: String?

    private var isReadOnly: Bool { request.status == .completed }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(chatService.messages) { msg in
                                ChatMessageRow(message: msg, isFromMe: msg.senderId == Auth.auth().currentUser?.uid)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatService.messages.count) { _, newCount in
                        if newCount > 0, let last = chatService.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = chatService.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }

                    if isReadOnly {
                        Text("This request is completed. Chat is closed.")
                            .font(AppTextStyle.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                    } else {
                        VStack(spacing: 6) {
                            if let shareLocationError {
                                Text(shareLocationError)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                            HStack(spacing: 8) {
                                Button {
                                    Task { await shareLocation() }
                                } label: {
                                    Image(systemName: "location.fill")
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.primaryGreen)
                                }
                                .disabled(isSharingLocation || isSending)
                                TextField("Message", text: $inputText, axis: .vertical)
                                    .lineLimit(1...4)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    Task { await send() }
                                } label: {
                                    if isSending {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.primaryGreen)
                                    }
                                }
                                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.primaryGreen)
            .task {
                chatService.startListeningMessages(requestId: request.id)
            }
            .onDisappear {
                chatService.stopMessagesListener()
            }
        }
    }

    private func send() async {
        let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        await MainActor.run {
            isSending = true
            inputText = ""
        }
        do {
            try await chatService.sendMessage(requestId: request.id, text: t)
            await MainActor.run { isSending = false }
        } catch {
            await MainActor.run { isSending = false }
        }
    }

    private func shareLocation() async {
        await MainActor.run {
            isSharingLocation = true
            shareLocationError = nil
        }
        let coord = await LocationManager.shared.requestLocationAndGetCoordinates()
        guard let coord else {
            await MainActor.run {
                isSharingLocation = false
                shareLocationError = "Location unavailable. Enable location or try again."
            }
            return
        }
        do {
            try await chatService.sendLocationMessage(requestId: request.id, latitude: coord.latitude, longitude: coord.longitude)
            await MainActor.run {
                isSharingLocation = false
                shareLocationError = nil
            }
        } catch {
            await MainActor.run {
                isSharingLocation = false
                shareLocationError = error.localizedDescription
            }
        }
    }
}

private struct ChatMessageRow: View {
    let message: Message
    let isFromMe: Bool

    var body: some View {
        VStack(alignment: message.type == .system ? .center : (isFromMe ? .trailing : .leading), spacing: 4) {
            switch message.type {
            case .system:
                if let text = message.text {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            case .location:
                LocationMessageCard(latitude: message.latitude, longitude: message.longitude, isFromMe: isFromMe)
            case .text:
                if let text = message.text {
                    HStack {
                        if isFromMe { Spacer(minLength: 48) }
                        Text(text)
                            .font(.body)
                            .padding(10)
                            .background(isFromMe ? AppTheme.primaryGreen.opacity(0.2) : Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        if !isFromMe { Spacer(minLength: 48) }
                    }
                }
            }
            Text(MessageTimestampFormatter.format(message.createdAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct LocationMessageCard: View {
    let latitude: Double?
    let longitude: Double?
    let isFromMe: Bool

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 8) {
                Text("Shared Location")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if let lat = latitude, let lng = longitude,
                   let url = URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)") {
                    Link(destination: url) {
                        Text("Open in Maps")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.primaryGreen)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: 200, alignment: .leading)
            .background(isFromMe ? AppTheme.primaryGreen.opacity(0.15) : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !isFromMe { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Post request sheet

private struct PostCommunityRequestSheet: View {
    let caretakerNumber: String
    let latitude: Double?
    let longitude: Double?
    @Binding var postError: String?
    var onPost: () -> Void
    var onCancel: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var isPosting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textContentType(.none)
                } header: {
                    Text("Help request")
                }

                if let postError {
                    Section {
                        Text(postError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await post() }
                    } label: {
                        if isPosting {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            Text("Post")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                    .tint(AppTheme.primaryGreen)

                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .foregroundStyle(AppTheme.primaryGreen)
                    .disabled(isPosting)
                }
            }
            .navigationTitle("Post Help Request")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.primaryGreen)
        }
    }

    private func post() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var lat = latitude
        var lng = longitude
        if lat == nil || lng == nil {
            if let firebaseUser = Auth.auth().currentUser,
               let appUser = try? await UserService.shared.fetchUser(for: firebaseUser),
               let a = appUser.latitude, let b = appUser.longitude {
                lat = a
                lng = b
            }
        }
        guard let lat = lat, let lng = lng else {
            await MainActor.run {
                postError = "Location required. Please use \"Update Location\" in the toolbar first."
            }
            return
        }
        await MainActor.run {
            isPosting = true
            postError = nil
        }
        do {
            try await CommunityService.shared.createRequest(
                title: t,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                caretakerNumber: caretakerNumber,
                latitude: lat,
                longitude: lng
            )
            await MainActor.run {
                isPosting = false
                onPost()
            }
        } catch {
            await MainActor.run {
                isPosting = false
                postError = error.localizedDescription
            }
        }
    }
}

// MARK: - Community: Open + My Accepted

struct CommunityOpenRequestsView: View {
    @StateObject private var service = CommunityService.shared
    @State private var chatRequest: CommunityRequest?
    @State private var userLocation: (lat: Double, lng: Double)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Open help requests")
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.white)

                if userLocation == nil {
                    Text("Loading your location…")
                        .font(AppTextStyle.secondary)
                        .foregroundStyle(.white.opacity(0.9))
                } else if let msg = service.errorMessage {
                    Text(msg)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.red)
                } else if service.openRequests.isEmpty {
                    Text("No open requests within 50km right now.")
                        .font(AppTextStyle.secondary)
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    ForEach(service.openRequests) { request in
                        OpenRequestCard(request: request)
                    }
                }

                Text("My Accepted Requests")
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                if service.acceptedByMeRequests.isEmpty {
                    Text("You haven't accepted any requests yet.")
                        .font(AppTextStyle.secondary)
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    ForEach(service.acceptedByMeRequests) { request in
                        AcceptedByMeCard(request: request, onOpenChat: { chatRequest = request })
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .task {
            await loadUserAndStartListeners()
        }
        .onDisappear {
            service.stopOpenListener()
            service.stopAcceptedByMeListener()
        }
        .sheet(item: $chatRequest) { request in
            CommunityChatView(request: request)
        }
    }

    private func loadUserAndStartListeners() async {
        guard let firebaseUser = Auth.auth().currentUser,
              let appUser = try? await UserService.shared.fetchUser(for: firebaseUser),
              let lat = appUser.latitude,
              let lng = appUser.longitude else {
            await MainActor.run { userLocation = nil }
            return
        }
        await MainActor.run { userLocation = (lat, lng) }
        service.startListeningOpenRequests(userLat: lat, userLng: lng)
        service.startListeningAcceptedByMe()
    }
}

private struct OpenRequestCard: View {
    let request: CommunityRequest
    @State private var isAccepting = false
    @State private var acceptError: String?
    @State private var showAcceptSheet = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(request.title)
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.primary)
                Text(request.description)
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.secondary)
                Text("Caretaker #\(request.caretakerNumber)")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)

                if let acceptError {
                    Text(acceptError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Button {
                    showAcceptSheet = true
                } label: {
                    if isAccepting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.9)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Accept")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryGreenButtonStyle())
                .disabled(isAccepting)
            }
        }
        .sheet(isPresented: $showAcceptSheet) {
            AcceptRequestSheet(
                requestId: request.id,
                onSavedAndAccepted: {
                    showAcceptSheet = false
                    isAccepting = false
                },
                onCancel: {
                    showAcceptSheet = false
                    isAccepting = false
                }
            )
        }
    }
}

private struct AcceptRequestSheet: View {
    let requestId: String
    var onSavedAndAccepted: () -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var phone = ""
    @State private var helperTime = ""
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Time you can help", text: $helperTime)
                        .textContentType(.none)
                } header: {
                    Text("Your details")
                } footer: {
                    Text("Add your name, phone, and when you can help. The caregiver will use this to reach you.")
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await saveAndAccept() }
                    } label: {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            Text("Save & Accept")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        isSaving
                    )
                    .tint(AppTheme.primaryGreen)

                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .foregroundStyle(AppTheme.primaryGreen)
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Accept request")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.primaryGreen)
            .task {
                await prefillIfNeeded()
            }
        }
    }

    private func prefillIfNeeded() async {
        guard let firebaseUser = Auth.auth().currentUser,
              let appUser = try? await UserService.shared.fetchUser(for: firebaseUser) else { return }
        await MainActor.run {
            if !appUser.name.isEmpty { name = appUser.name }
            if let p = appUser.phone, !p.isEmpty { phone = p }
        }
    }

    private func saveAndAccept() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = helperTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else { return }
        await MainActor.run {
            isSaving = true
            saveError = nil
        }
        do {
            try await UserService.shared.updateCurrentUserProfile(name: trimmedName, phone: trimmedPhone)
            try await CommunityService.shared.acceptRequest(
                requestId: requestId,
                helperName: trimmedName,
                helperPhone: trimmedPhone,
                helperTime: trimmedTime.isEmpty ? "—" : trimmedTime
            )
            await MainActor.run {
                isSaving = false
                onSavedAndAccepted()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }
}

private struct AcceptedByMeCard: View {
    let request: CommunityRequest
    var onOpenChat: () -> Void
    @State private var isCompleting = false
    @State private var completeError: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(request.title)
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.primary)
                Text(request.description)
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.secondary)

                if let completeError {
                    Text(completeError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                if request.status == .accepted {
                    Button {
                        onOpenChat()
                    } label: {
                        Text("Open Chat")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryGreenButtonStyle())

                    Button {
                        Task { await markCompleted() }
                    } label: {
                        if isCompleting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Mark Completed")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.primaryGreen)
                    .disabled(isCompleting)
                }

                if request.status == .completed {
                    Text("Completed")
                        .font(AppTextStyle.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func markCompleted() async {
        await MainActor.run {
            isCompleting = true
            completeError = nil
        }
        do {
            try await CommunityService.shared.markCompleted(requestId: request.id)
            await MainActor.run { isCompleting = false }
        } catch {
            await MainActor.run {
                isCompleting = false
                completeError = error.localizedDescription
            }
        }
    }
}
