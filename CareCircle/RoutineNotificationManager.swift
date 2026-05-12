import Foundation
import UserNotifications

// MARK: - Local routine reminders (daily at reminder time)

final class RoutineNotificationManager {
    static let shared = RoutineNotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Call before scheduling; routine still saves if permission is denied.
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            break
        @unknown default:
            break
        }
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
        return granted
    }

    /// Schedules a daily repeating local notification at routine's reminder time. Idempotent: use same id to replace.
    func scheduleRoutineNotification(routine: Routine) {
        guard routine.reminderEnabled,
              let time = routine.reminderTime else {
            cancelRoutineNotification(routineId: routine.id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Routine reminder"
        content.body = "Time for: \(routine.title)"
        content.sound = .default

        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(routineId: routine.id),
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in }
    }

    /// Removes the scheduled notification for this routine.
    func cancelRoutineNotification(routineId: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(routineId: routineId)]
        )
    }

    private func notificationIdentifier(routineId: String) -> String {
        "routine_\(routineId)"
    }
}
