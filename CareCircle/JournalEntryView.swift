import SwiftUI

// MARK: - Journal entry (one date: text + Reflect → AI reflection card)

struct JournalEntryView: View {
    let date: Date
    let onDismiss: () -> Void

    @StateObject private var store = JournalStore.shared
    @State private var userText: String = ""
    @State private var aiReflection: String = ""
    @State private var isReflecting: Bool = false
    @FocusState private var isEditorFocused: Bool

    private var existingEntry: JournalEntry? { store.entry(for: date) }

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    textEditorSection
                    reflectButton
                    if !aiReflection.isEmpty {
                        reflectionCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadExistingEntry()
        }
        .onDisappear {
            saveDraftIfNeeded()
            onDismiss()
        }
        .overlay {
            if isReflecting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Reflecting…")
                    .tint(.white)
            }
        }
    }

    private var navigationTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Journal — \(formatter.string(from: date))"
    }

    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if userText.isEmpty {
                    Text("Write what you felt or experienced today…")
                        .font(AppTextStyle.body)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $userText)
                    .font(AppTextStyle.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(8)
                    .focused($isEditorFocused)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var reflectButton: some View {
        Button {
            Task { await reflect() }
        } label: {
            Text("Reflect")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryGreenButtonStyle())
        .disabled(userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isReflecting)
        .accessibilityLabel("Generate reflection")
    }

    private var reflectionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reflection")
                    .font(AppTextStyle.secondary.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryGreen)
                Text(aiReflection)
                    .font(AppTextStyle.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func loadExistingEntry() {
        if let entry = existingEntry {
            userText = entry.userText
            aiReflection = entry.aiReflection
        } else {
            userText = ""
            aiReflection = ""
        }
    }

    private func reflect() async {
        let text = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isReflecting = true
        defer { isReflecting = false }
        let reflection = await store.generateReflection(userText: text)
        await MainActor.run {
            aiReflection = reflection
            saveEntry()
        }
    }

    private func saveEntry() {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let entry = JournalEntry(
            date: startOfDay,
            userText: userText.trimmingCharacters(in: .whitespacesAndNewlines),
            aiReflection: aiReflection,
            createdAt: existingEntry?.createdAt ?? Date()
        )
        store.saveEntry(entry)
    }

    private func saveDraftIfNeeded() {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let entry = JournalEntry(
            date: startOfDay,
            userText: trimmed,
            aiReflection: aiReflection,
            createdAt: existingEntry?.createdAt ?? Date()
        )
        store.saveEntry(entry)
    }
}
