import Foundation

// MARK: - In-app indicator for new social worker replies (no push)

private let seenIdsKey = "careCircle.seenReplyRequestIds"

final class UnseenRepliesManager: ObservableObject {
    static let shared = UnseenRepliesManager()

    @Published private(set) var unseenCount: Int = 0

    private init() {}

    /// Call after fetching caregiver requests. Updates unseenCount from answered requests not yet seen.
    func updateUnseenCount(answeredRequestIds: [String]) {
        let seen = Set(UserDefaults.standard.stringArray(forKey: seenIdsKey) ?? [])
        unseenCount = answeredRequestIds.filter { !seen.contains($0) }.count
    }

    /// Call when caregiver opens Social tab or views a reply. Marks these ids as seen.
    func markAsSeen(requestIds: [String]) {
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenIdsKey) ?? [])
        seen.formUnion(requestIds)
        UserDefaults.standard.set(Array(seen), forKey: seenIdsKey)
        unseenCount = max(0, unseenCount - requestIds.count)
    }

    /// Refreshes count from current caregiver requests. Call from dashboard when needed.
    func refreshUnseenCount() async {
        do {
            let requests = try await CareRequestService.shared.fetchCaregiverRequests()
            let answeredIds = requests.filter(\.isAnswered).map(\.id)
            await MainActor.run {
                updateUnseenCount(answeredRequestIds: answeredIds)
            }
        } catch {
            await MainActor.run { unseenCount = 0 }
        }
    }
}
