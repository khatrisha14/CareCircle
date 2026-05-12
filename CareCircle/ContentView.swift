//
//  ContentView.swift
//  CareCircle
//
//  Created by naman yadav on 2/5/26.
//

import SwiftUI
import FirebaseAuth
import UIKit

// MARK: - Navigation routes (used by RootView auth flow)

enum AppRoute: Hashable {
    case login
    case caregiverDashboard
    case socialWorkerDashboard
    case communityDashboard
}

/// Authenticated app content: location gate + role-based dashboard. Shown by RootView when sessionUser is set.
struct ContentView: View {
    @Binding var sessionUser: AppUser?
    var onLogout: () -> Void

    var body: some View {
        Group {
            if let user = sessionUser {
                if user.hasLocation {
                    NavigationStack {
                        dashboardView(for: user, onLogout: onLogout)
                    }
                } else {
                    LocationCaptureView {
                        Task { await refetchSessionUser() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardView(for user: AppUser, onLogout: @escaping () -> Void) -> some View {
        switch user.role {
        case .caregiver:
            CaregiverDashboardView(onLogout: onLogout, onUpdateLocation: { Task { await refetchSessionUser() } })
        case .socialWorker:
            SocialWorkerDashboardView(onLogout: onLogout, onUpdateLocation: { Task { await refetchSessionUser() } })
        case .community:
            CommunityDashboardView(onLogout: onLogout, onUpdateLocation: { Task { await refetchSessionUser() } })
        }
    }

    private func refetchSessionUser() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        if let appUser = try? await UserService.shared.fetchUser(for: firebaseUser) {
            await MainActor.run {
                sessionUser = appUser
            }
        }
    }
}

// MARK: - Caregiver tab (top menu)

private enum CaregiverTab: String, CaseIterable, Identifiable {
    case routines
    case communityAccess
    case declutter
    case journal
    case social

    var id: String { rawValue }

    /// Tabs shown in the caregiver menu bar. Journal & Declutter are temporarily hidden (code and views unchanged).
    static var visibleTabs: [CaregiverTab] { [.routines, .communityAccess, .social] }

    var title: String {
        switch self {
        case .routines: return "Routines"
        case .communityAccess: return "Community"
        case .declutter: return "Declutter"
        case .journal: return "Journal"
        case .social: return "Social"
        }
    }

    var iconName: String {
        switch self {
        case .routines: return "house.fill"
        case .communityAccess: return "person.3.fill"
        case .declutter: return "brain"
        case .journal: return "square.and.pencil"
        case .social: return "person.2.fill"
        }
    }
}

private struct CaregiverMenuBar: View {
    @Binding var selectedTab: CaregiverTab
    var socialUnseenCount: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CaregiverTab.visibleTabs) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                            if tab == .social, socialUnseenCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 6, y: -6)
                            }
                        }
                        Text(tab.title)
                            .font(AppTextStyle.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedTab == tab ? AppTheme.primaryGreen.opacity(0.9) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab == .social && socialUnseenCount > 0 ? "\(tab.title), \(socialUnseenCount) new replies" : tab.title)
                .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.screenGradient.opacity(0.98))
    }
}

// MARK: - Dashboards

struct CaregiverDashboardView: View {
    var onLogout: () -> Void
    var onUpdateLocation: () -> Void
    @State private var selectedTab: CaregiverTab = .routines
    @State private var routines: [Routine] = []
    @State private var completionState: [String: Bool] = [:]
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedIntensity: CareIntensity? = nil
    @State private var showRoutineSheet: Bool = false
    @State private var routineToEdit: Routine?
    @State private var showCareReportFlow: Bool = false
    @State private var showUpdateLocation: Bool = false
    @StateObject private var unseenReplies = UnseenRepliesManager.shared

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()
            VStack(spacing: 0) {
                CaregiverMenuBar(selectedTab: $selectedTab, socialUnseenCount: unseenReplies.unseenCount)
                contentForSelectedTab
            }
        }
        .navigationTitle("Caregiver")
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
                Button("Update Location") {
                    showUpdateLocation = true
                }
                .foregroundStyle(AppTheme.primaryGreen)
            }
        }
        .task {
            await loadRoutines()
            await UnseenRepliesManager.shared.refreshUnseenCount()
        }
        .sheet(isPresented: $showUpdateLocation) {
            LocationCaptureView(
                onComplete: {
                    onUpdateLocation()
                    showUpdateLocation = false
                },
                onSkip: { showUpdateLocation = false }
            )
        }
        .sheet(isPresented: $showRoutineSheet) {
            AddRoutineView(
                initialRoutine: routineToEdit,
                onCancel: {
                    showRoutineSheet = false
                    routineToEdit = nil
                },
                onSaved: {
                    showRoutineSheet = false
                    routineToEdit = nil
                    Task { await loadRoutines() }
                }
            )
        }
        .sheet(isPresented: $showCareReportFlow) {
            CareReportFlowView(
                initialIntensity: careReportIntensityString,
                completionSummary: (
                    completed: completionState.values.filter { $0 }.count,
                    total: routines.count
                ),
                onDismiss: { showCareReportFlow = false }
            )
        }
    }

    @ViewBuilder
    private var contentForSelectedTab: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 24) {
                caregiverTabContent
            }
        } else {
            caregiverTabContent
        }
    }

    @ViewBuilder
    private var caregiverTabContent: some View {
        switch selectedTab {
        case .routines:
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    routinesSection
                    summarySection
                    reflectionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        case .communityAccess:
            CommunityAccessView()
        case .declutter:
            DeclutterView()
        case .journal:
            JournalCalendarView()
        case .social:
            SocialConnectView()
        }
    }

    private var careReportIntensityString: String {
        switch selectedIntensity {
        case .low: return "Low"
        case .medium: return "Moderate"
        case .high: return "High"
        case .none: return "Low"
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back")
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.white)

                Text(Self.formattedToday)
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Button {
                routineToEdit = nil
                showRoutineSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
                    .background(Circle().fill(AppTheme.primaryGreen))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    .accessibilityLabel("Add routine")
            }
        }
    }

    private var routinesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
            Text("Today’s routines")
                .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.primary)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.top, 8)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(AppTextStyle.secondary)
                    .foregroundColor(.red)
            } else if routines.isEmpty {
                Text("You don’t have any routines yet. You can add one with the plus button above.")
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(routines) { routine in
                        RoutineRowView(
                            routine: routine,
                            isCompleted: completionState[routine.id] ?? false,
                            toggleCompleted: {
                                toggleCompleted(routine)
                            },
                            editRoutine: {
                                routineToEdit = routine
                                showRoutineSheet = true
                            },
                            deleteRoutine: {
                                deleteRoutine(routine)
                            }
                        )
                    }
                }
            }
            }
        }
    }

    private var summarySection: some View {
        let totalCount = routines.count
        let completedCount = completionState.values.filter { $0 }.count

        return GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily summary")
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.primary)

                Text("You completed \(completedCount) of \(totalCount) routines today.")
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reflectionSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reflection")
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.primary)

                Text("How intense was caregiving today?")
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(CareIntensity.allCases) { level in
                        Button {
                            selectedIntensity = level
                        } label: {
                            Text(level.label)
                                .font(AppTextStyle.secondary.weight(.medium))
                                .foregroundStyle(selectedIntensity == level ? .white : .primary)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedIntensity == level ? AppTheme.primaryGreen : AppTheme.cardSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            selectedIntensity == level ? AppTheme.primaryGreen : Color(.separator),
                                            lineWidth: selectedIntensity == level ? 1.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(level.accessibilityLabel)
                    }
                }

                Button {
                    showCareReportFlow = true
                } label: {
                    Text("Generate care report")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryGreenButtonStyle())
            }
        }
    }

    // MARK: - Helpers

    private func toggleCompleted(_ routine: Routine) {
        let current = completionState[routine.id] ?? false
        Task {
            do {
                try await RoutineCompletionService.shared.setCompletion(routineId: routine.id, isCompleted: !current)
                await loadCompletions()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadRoutines() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await RoutineService.shared.fetchRoutinesForCurrentCaregiver()
            await MainActor.run {
                routines = fetched
            }
            await loadCompletions()
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadCompletions() async {
        do {
            let completions = try await RoutineCompletionService.shared.fetchCompletionsForToday()
            var state: [String: Bool] = [:]
            for c in completions {
                state[c.routineId] = c.isCompleted
            }
            await MainActor.run {
                completionState = state
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteRoutine(_ routine: Routine) {
        RoutineNotificationManager.shared.cancelRoutineNotification(routineId: routine.id)
        if let path = routine.imagePath {
            ImageStorageService.shared.deleteImage(at: path)
        }
        Task {
            do {
                try await RoutineService.shared.deleteRoutine(routine)
                await MainActor.run {
                    routines.removeAll { $0.id == routine.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private static var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
}

// MARK: - Caregiver models & views

private enum CareIntensity: String, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .low: return "Low intensity day"
        case .medium: return "Medium intensity day"
        case .high: return "High intensity day"
        }
    }
}

// MARK: - Image Picker (camera or library, one image, no editing)

private struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private enum RoutineSymbols {
    static let all: [String] = [
        "pills.fill", "heart.fill", "bed.double.fill", "cross.case.fill",
        "figure.walk", "drop.fill", "clock.fill", "calendar",
        "hand.raised.fill", "leaf.fill", "bolt.heart.fill", "staroflife.fill"
    ]
}

private struct RoutineRowView: View {
    let routine: Routine
    let isCompleted: Bool
    let toggleCompleted: () -> Void
    let editRoutine: () -> Void
    let deleteRoutine: () -> Void

    private var displaySymbol: String {
        RoutineSymbols.all.contains(routine.symbol) ? routine.symbol : "checkmark.circle.fill"
    }

    private var thumbnailImage: UIImage? {
        guard let path = routine.imagePath else { return nil }
        return ImageStorageService.shared.loadImage(from: path)
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let img = thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: displaySymbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.primaryGreen)
                        )
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(routine.title)
                        .font(AppTextStyle.secondary.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if routine.reminderEnabled {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.primaryGreen)
                            .accessibilityLabel("Has reminder")
                    }
                }
                Text(routine.note)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(spacing: 8) {
                Button(action: toggleCompleted) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isCompleted ? .accentColor : Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCompleted ? "Mark routine as not completed" : "Mark routine as completed")

                Button(action: editRoutine) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryGreen)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit routine \(routine.title)")

                Button(action: deleteRoutine) {
                    Text("Delete")
                        .font(AppTextStyle.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete routine \(routine.title)")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.06),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
    }
}

// MARK: - Add / Edit Routine

struct AddRoutineView: View {
    var initialRoutine: Routine?

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var selectedSymbol: String = RoutineSymbols.all[0]
    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Self.defaultReminderTime
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    // Photo: one image per routine, stored locally
    @State private var selectedImage: UIImage? = nil
    @State private var existingImagePath: String? = nil
    @State private var removedPhoto: Bool = false
    @State private var showPhotoActionSheet: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

    let onCancel: () -> Void
    let onSaved: () -> Void

    private static var defaultReminderTime: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .textContentType(.none)
                } header: {
                    Text("Routine details")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
                        ForEach(RoutineSymbols.all, id: \.self) { name in
                            Button {
                                selectedSymbol = name
                            } label: {
                                Image(systemName: name)
                                    .font(.title2)
                                    .foregroundStyle(selectedSymbol == name ? .white : .primary)
                                    .frame(width: 52, height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(selectedSymbol == name ? AppTheme.primaryGreen : Color(.secondarySystemBackground))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Symbol \(name)")
                            .accessibilityAddTraits(selectedSymbol == name ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Symbol")
                }

                Section {
                    Toggle("Remind me", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Optional. You’ll get a daily reminder at the time you choose.")
                }

                Section {
                    if let img = selectedImage ?? (existingImagePath.flatMap { ImageStorageService.shared.loadImage(from: $0) }), !removedPhoto {
                        HStack(spacing: 12) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Button("Remove photo", role: .destructive) {
                                selectedImage = nil
                                removedPhoto = true
                            }
                        }
                    } else {
                        Button("Add Photo") {
                            showPhotoActionSheet = true
                        }
                        .foregroundStyle(AppTheme.primaryGreen)
                    }
                } header: {
                    Text("Photo")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await saveRoutine() }
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
                            Text("Save")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .tint(AppTheme.primaryGreen)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .foregroundStyle(AppTheme.primaryGreen)
                    .disabled(isSaving)
                }
            }
            .navigationTitle(initialRoutine == nil ? "Add routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.primaryGreen)
            .onAppear {
                if let r = initialRoutine {
                    title = r.title
                    note = r.note
                    selectedSymbol = r.symbol
                    reminderEnabled = r.reminderEnabled
                    reminderTime = r.reminderTime ?? Self.defaultReminderTime
                    existingImagePath = r.imagePath
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showPhotoActionSheet, titleVisibility: .visible) {
                Button("Take Photo") {
                    imagePickerSourceType = .camera
                    showImagePicker = true
                }
                Button("Choose from Library") {
                    imagePickerSourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Select a photo for this routine.")
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imagePickerSourceType, image: $selectedImage)
                    .ignoresSafeArea()
            }
        }
    }

    private func saveRoutine() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        do {
            var finalImagePath: String?
            if removedPhoto || selectedImage == nil && existingImagePath == nil {
                if let old = existingImagePath, !old.isEmpty {
                    ImageStorageService.shared.deleteImage(at: old)
                }
                finalImagePath = nil
            } else if let newImage = selectedImage {
                if let old = existingImagePath, !old.isEmpty {
                    ImageStorageService.shared.deleteImage(at: old)
                }
                finalImagePath = ImageStorageService.shared.saveImage(newImage)
            } else {
                finalImagePath = existingImagePath
            }

            let routine: Routine
            if let existing = initialRoutine {
                routine = Routine(
                    id: existing.id,
                    caregiverId: existing.caregiverId,
                    title: trimmedTitle,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                    symbol: selectedSymbol,
                    createdAt: existing.createdAt,
                    reminderEnabled: reminderEnabled,
                    reminderTime: reminderEnabled ? reminderTime : nil,
                    imagePath: finalImagePath
                )
                try await RoutineService.shared.updateRoutine(routine)
            } else {
                routine = try await RoutineService.shared.createRoutine(
                    title: trimmedTitle,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                    symbol: selectedSymbol,
                    reminderEnabled: reminderEnabled,
                    reminderTime: reminderEnabled ? reminderTime : nil,
                    imagePath: finalImagePath
                )
            }

            if reminderEnabled {
                _ = await RoutineNotificationManager.shared.requestPermissionIfNeeded()
                RoutineNotificationManager.shared.scheduleRoutineNotification(routine: routine)
            } else {
                RoutineNotificationManager.shared.cancelRoutineNotification(routineId: routine.id)
            }

            await MainActor.run {
                isSaving = false
                onSaved()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum SocialWorkerTab: String, CaseIterable, Identifiable {
    case requests = "Requests"
    case myPosts = "My Posts"
    var id: String { rawValue }
}

private struct SocialWorkerMenuBar: View {
    @Binding var selectedTab: SocialWorkerTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SocialWorkerTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(AppTextStyle.secondary.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedTab == tab ? AppTheme.primaryGreen.opacity(0.9) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.screenGradient.opacity(0.98))
    }
}

struct SocialWorkerDashboardView: View {
    var onLogout: () -> Void
    var onUpdateLocation: () -> Void
    @State private var selectedTab: SocialWorkerTab = .requests
    @State private var showUpdateLocation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SocialWorkerMenuBar(selectedTab: $selectedTab)
                Group {
                    if selectedTab == .requests {
                        SocialWorkerCareRequestsView(onLogout: onLogout)
                    } else {
                        SocialWorkerMyPostsView(onLogout: onLogout)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Update Location") {
                    showUpdateLocation = true
                }
                .foregroundStyle(AppTheme.primaryGreen)
            }
        }
        .sheet(isPresented: $showUpdateLocation) {
            LocationCaptureView(
                onComplete: {
                    onUpdateLocation()
                    showUpdateLocation = false
                },
                onSkip: { showUpdateLocation = false }
            )
        }
    }
}

// MARK: - Community dashboard (open requests + accept)

struct CommunityDashboardView: View {
    var onLogout: () -> Void
    var onUpdateLocation: () -> Void
    @State private var showUpdateLocation = false
    var body: some View {
        ZStack {
            AppTheme.screenGradient.ignoresSafeArea()
            CommunityOpenRequestsView()
        }
        .navigationTitle("Community Access")
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
                Button("Update Location") {
                    showUpdateLocation = true
                }
                .foregroundStyle(AppTheme.primaryGreen)
            }
        }
        .sheet(isPresented: $showUpdateLocation) {
            LocationCaptureView(
                onComplete: {
                    onUpdateLocation()
                    showUpdateLocation = false
                },
                onSkip: { showUpdateLocation = false }
            )
        }
    }
}

#Preview {
    RootView()
}
