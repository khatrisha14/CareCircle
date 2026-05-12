import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Journal store (local persistence + cleanup + reflection)

final class JournalStore: ObservableObject {
    static let shared = JournalStore()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let retentionDays: Int = 7

    private var fileURL: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let journalDir = dir.appendingPathComponent("Journal", isDirectory: true)
        if !fileManager.fileExists(atPath: journalDir.path) {
            try? fileManager.createDirectory(at: journalDir, withIntermediateDirectories: true)
        }
        return journalDir.appendingPathComponent("entries.json")
    }

    @Published private(set) var entries: [JournalEntry] = []

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadEntries()
        runCleanupIfNeeded()
    }

    // MARK: - Load / save

    func loadEntries() {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([JournalEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.date > $1.date }
    }

    func saveEntry(_ entry: JournalEntry) {
        runCleanupIfNeeded()
        let key = JournalEntry.dayKey(for: entry.date)
        entries.removeAll { JournalEntry.dayKey(for: $0.date) == key }
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        persist()
    }

    func entry(for date: Date) -> JournalEntry? {
        let key = JournalEntry.dayKey(for: date)
        return entries.first { JournalEntry.dayKey(for: $0.date) == key }
    }

    func datesWithEntries(in calendar: Calendar) -> Set<Date> {
        let cal = calendar
        return Set(entries.map { cal.startOfDay(for: $0.date) })
    }

    private func persist() {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL)
    }

    // MARK: - Cleanup (silent, automatic)

    /// Call on app launch or when journal view appears. Removes entries older than 7 days.
    func runCleanupIfNeeded() {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let startOfCutoff = cal.startOfDay(for: cutoff)
        let before = entries.count
        entries.removeAll { cal.startOfDay(for: $0.date) < startOfCutoff }
        if entries.count != before {
            persist()
        }
    }

    // MARK: - AI reflection

    /// Generates one short calm, observational paragraph. Uses Apple Foundation Model on iOS 26+ when available; otherwise uses on-device fallback.
    func generateReflection(userText: String) async -> String {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let result = await generateWithFoundationModel(userText: trimmed)
            if let result = result, !result.isEmpty {
                return result
            }
            #if DEBUG
            print("[CareCircle] Using fallback: Foundation Model returned nil or empty.")
            #endif
        } else {
            #if DEBUG
            print("[CareCircle] Using fallback: running on iOS < 26. Use an iOS 26 simulator/device for AI reflections.")
            #endif
        }
        #else
        #if DEBUG
        print("[CareCircle] Using fallback: FoundationModels not available (check SDK/target).")
        #endif
        #endif
        return fallbackReflection(for: trimmed)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModel(userText: String) async -> String? {
        let instructions = """
        You write exactly one short paragraph (3 to 5 sentences). Tone: calm, observational, supportive.
        Do not give advice, diagnose, ask questions, offer solutions, or mention being an AI.
        Simply reflect back what you notice in the writer's experience in a gentle, descriptive way.
        """
        let prompt = "Based only on this journal entry, write one short reflective paragraph as described in your instructions. Journal entry: \(userText)"
        do {
            let session = LanguageModelSession(instructions: instructions)
            let options = GenerationOptions(maximumResponseTokens: 150)
            let response = try await session.respond(to: prompt, options: options)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            #if DEBUG
            print("[CareCircle] Foundation Model reflection failed: \(error)")
            #endif
            return nil
        }
    }
    #endif

    /// Fallback when Foundation Model is unavailable (pre–iOS 26 or simulator without Apple Intelligence).
    private func fallbackReflection(for userText: String) -> String {
        let options = [
            "What you wrote today shows a lot of care and awareness. Holding space for these experiences is a gentle way to tend to yourself.",
            "Noticing and naming what you feel takes courage. This kind of reflection can help things feel a little more manageable.",
            "Your words capture a real moment in your day. Acknowledging it like this is a supportive step.",
        ]
        return options[abs(userText.hashValue) % options.count]
    }
}
