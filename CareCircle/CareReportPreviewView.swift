import SwiftUI
import UIKit
import Photos

/// Preview the care report as an image (JPEG). Save to Photos, Share, or Send to Social Worker.
struct CareReportPreviewView: View {
    let imageURL: URL
    /// When non-nil, shows "Send to Social Worker" and allows sending request data to Firestore.
    var sendPayload: (draft: CareReportDraft, completionSummary: (completed: Int, total: Int), date: Date)? = nil
    let onDismiss: () -> Void

    @State private var image: UIImage?
    @State private var showShareSheet = false
    @State private var saveMessage: String? = nil
    @State private var saveError: String? = nil
    @State private var showSendSheet = false
    @State private var sentForReviewMessage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                    } else {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, minHeight: 300)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300)

                VStack(spacing: 12) {
                    Button {
                        saveToPhotos()
                    } label: {
                        Label("Save to Photos", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(image == nil)

                    if sendPayload != nil {
                        Button {
                            showSendSheet = true
                        } label: {
                            Label("Send to Social Worker", systemImage: "person.badge.plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .disabled(image == nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Care Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                loadImage()
            }
            .alert("Saved", isPresented: .init(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })) {
                Button("OK", role: .cancel) { saveMessage = nil }
            } message: {
                if let msg = saveMessage { Text(msg) }
            }
            .alert("Error", isPresented: .init(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                if let msg = saveError { Text(msg) }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = image {
                    ShareSheet(items: [img])
                }
            }
            .sheet(isPresented: $showSendSheet) {
                if let payload = sendPayload {
                    SendToSocialWorkerSheet(
                        payload: payload,
                        onSend: {
                            showSendSheet = false
                            sentForReviewMessage = true
                        },
                        onCancel: { showSendSheet = false }
                    )
                }
            }
            .overlay {
                if sentForReviewMessage {
                    SentForReviewBanner(onDismiss: { sentForReviewMessage = false })
                }
            }
        }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: imageURL), let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    image = img
                }
            }
        }
    }

    private func saveToPhotos() {
        guard let img = image else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    saveError = "Photo library access is needed to save the report."
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: img)
                } completionHandler: { ok, error in
                    DispatchQueue.main.async {
                        if ok {
                            saveMessage = "Report saved to your Photos."
                        } else {
                            saveError = error?.localizedDescription ?? "Could not save to Photos."
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Send to Social Worker sheet

private struct SendToSocialWorkerSheet: View {
    let payload: (draft: CareReportDraft, completionSummary: (completed: Int, total: Int), date: Date)
    let onSend: () -> Void
    let onCancel: () -> Void

    @State private var questionText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Add a short question for the social worker (optional)", text: $questionText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .focused($isFieldFocused)

                Spacer(minLength: 20)
            }
            .padding(20)
            .navigationTitle("Send to Social Worker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(isSending)
                }
            }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .overlay {
                if isSending {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
        }
    }

    private func send() {
        isSending = true
        errorMessage = nil
        let requestPayload = CareRequestPayload(
            draft: payload.draft,
            completionSummary: payload.completionSummary,
            date: payload.date,
            questionText: questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task {
            do {
                try await CareRequestService.shared.sendCareRequest(requestPayload)
                await MainActor.run {
                    isSending = false
                    onSend()
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

// MARK: - Subtle "Sent for review" confirmation

private struct SentForReviewBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                Text("Sent for review")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .onTapGesture { onDismiss() }
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
