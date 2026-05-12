import SwiftUI

// MARK: - Care Report Flow (step-by-step; generates report image on completion)

struct CareReportFlowView: View {
    let initialIntensity: String
    let completionSummary: (completed: Int, total: Int)
    let onDismiss: () -> Void

    @State private var draft: CareReportDraft
    @State private var currentStepIndex: Int = 0
    @State private var optionalTextQ5: String = ""
    @State private var optionalTextQ7: String = ""
    @State private var generatedReportItem: GeneratedReportItem?
    @State private var isGenerating = false
    @State private var generationError: String?

    private var steps: [CareReportQuestion] {
        CareReportQuestionSet.flowSteps(answers: draft.answers)
    }

    private var currentQuestion: CareReportQuestion? {
        guard currentStepIndex >= 0, currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    private var progressText: String {
        "Step \(currentStepIndex + 1) of \(steps.count)"
    }

    private var isLastStep: Bool {
        currentStepIndex == steps.count - 1
    }

    init(initialIntensity: String, completionSummary: (completed: Int, total: Int), onDismiss: @escaping () -> Void) {
        self.initialIntensity = initialIntensity
        self.completionSummary = completionSummary
        self.onDismiss = onDismiss
        _draft = State(initialValue: CareReportDraft(intensity: initialIntensity))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    Text(progressText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))

                    if let question = currentQuestion {
                        Text(question.questionText)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        questionContent(question)

                        Spacer(minLength: 24)

                        HStack(spacing: 12) {
                            if currentStepIndex > 0 {
                                Button("Back") {
                                    currentStepIndex -= 1
                                    syncOptionalTextFromDraft()
                                }
                                .buttonStyle(SecondaryGreenButtonStyle())
                            }

                            Spacer()

                            if !question.isRequired {
                                Button("Skip") {
                                    if isLastStep {
                                        onDismiss()
                                    } else {
                                        currentStepIndex += 1
                                        syncOptionalTextFromDraft()
                                    }
                                }
                                .buttonStyle(SecondaryGreenButtonStyle())
                            }

                            Button(isLastStep ? "Review care report" : "Next") {
                                saveCurrentAnswer(for: question)
                                if isLastStep {
                                    generatePDFAndShowPreview()
                                } else {
                                    currentStepIndex += 1
                                    syncOptionalTextFromDraft()
                                }
                            }
                            .buttonStyle(PrimaryGreenButtonStyle())
                            .disabled(isLastStep && isGenerating)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Care report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundStyle(AppTheme.primaryGreen)
                }
            }
            .overlay {
                if isGenerating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Generating report…")
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            )) {
                Button("OK", role: .cancel) { generationError = nil }
            } message: {
                if let msg = generationError { Text(msg) }
            }
            .fullScreenCover(item: $generatedReportItem) { item in
                CareReportPreviewView(
                    imageURL: item.imageURL,
                    sendPayload: (draft: item.draft, completionSummary: item.completionSummary, date: item.date),
                    onDismiss: {
                        generatedReportItem = nil
                        onDismiss()
                    }
                )
            }
        }
    }

    private func generatePDFAndShowPreview() {
        isGenerating = true
        generationError = nil
        Task {
            defer { Task { @MainActor in isGenerating = false } }
            let date = Date()
            // Report is generated as JPEG on main thread (UIKit drawing)
            let url = await MainActor.run {
                ReportImageService.generateReportImage(
                    draft: draft,
                    completionSummary: completionSummary,
                    date: date
                )
            }
            guard let url = url else {
                await MainActor.run { generationError = "Could not create report image." }
                return
            }
            await MainActor.run {
                generatedReportItem = GeneratedReportItem(
                    imageURL: url,
                    draft: draft,
                    completionSummary: completionSummary,
                    date: date
                )
            }
        }
    }

    @ViewBuilder
    private func questionContent(_ question: CareReportQuestion) -> some View {
        switch question.answerType {
        case .singleChoice:
            singleChoiceOptions(question)
        case .multiChoice:
            multiChoiceOptions(question)
        case .optionalText:
            optionalTextField(question)
        }
    }

    private func singleChoiceOptions(_ question: CareReportQuestion) -> some View {
        let selected = draft.answers[question.id] as? String
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(question.options, id: \.self) { option in
                Button {
                    var next = draft.answers
                    next[question.id] = option
                    draft.answers = next
                } label: {
                    singleChoiceOptionLabel(option: option, isSelected: selected == option)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func singleChoiceOptionLabel(option: String, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack {
            Text(option)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.primaryGreen)
            }
        }
        .padding(14)
        .background(shape.fill(isSelected ? AppTheme.primaryGreen.opacity(0.15) : Color(.secondarySystemBackground)))
        .overlay(shape.strokeBorder(isSelected ? AppTheme.primaryGreen : Color.clear, lineWidth: 1.5))
    }

    private func multiChoiceOptions(_ question: CareReportQuestion) -> some View {
        let selected = (draft.answers[question.id] as? [String]) ?? []
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(question.options, id: \.self) { option in
                Button {
                    var next = draft.answers
                    var list = (next[question.id] as? [String]) ?? []
                    if list.contains(option) {
                        list.removeAll { $0 == option }
                    } else {
                        list.append(option)
                    }
                    next[question.id] = list.isEmpty ? [] : list
                    draft.answers = next
                } label: {
                    multiChoiceOptionLabel(option: option, isSelected: selected.contains(option))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func multiChoiceOptionLabel(option: String, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack {
            Text(option)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.primaryGreen)
            }
        }
        .padding(14)
        .background(shape.fill(isSelected ? AppTheme.primaryGreen.opacity(0.15) : Color(.secondarySystemBackground)))
        .overlay(shape.strokeBorder(isSelected ? AppTheme.primaryGreen : Color.clear, lineWidth: 1.5))
    }

    private func optionalTextField(_ question: CareReportQuestion) -> some View {
        let binding: Binding<String> = question.id == "q5"
            ? $optionalTextQ5
            : $optionalTextQ7
        let placeholder = question.id == "q5"
            ? "Briefly describe what happened (optional)"
            : "Anything you’d like to share (optional)"
        return TextField(placeholder, text: binding, axis: .vertical)
            .textFieldStyle(.plain)
            .padding(14)
            .lineLimit(4...8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    private func saveCurrentAnswer(for question: CareReportQuestion) {
        switch question.answerType {
        case .optionalText:
            let text = question.id == "q5" ? optionalTextQ5 : optionalTextQ7
            var next = draft.answers
            next[question.id] = text
            draft.answers = next
        default:
            break
        }
    }

    private func syncOptionalTextFromDraft() {
        optionalTextQ5 = draft.answers["q5"] as? String ?? ""
        optionalTextQ7 = draft.answers["q7"] as? String ?? ""
    }
}

private struct GeneratedReportItem: Identifiable {
    let id = UUID()
    let imageURL: URL
    let draft: CareReportDraft
    let completionSummary: (completed: Int, total: Int)
    let date: Date
}
