import Foundation
import UserNotifications

/// Tiny wrapper around UNUserNotificationCenter for the one notification we
/// schedule today: a nightly "rate dinner" reminder. Opt-in via Settings.
enum Notifications {
    private static let nightlyRatingId = "nightly-rating"

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Daily 8 PM nudge. Body is light so it doesn't feel naggy.
    static func scheduleNightlyRating() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [nightlyRatingId])

        let content = UNMutableNotificationContent()
        content.title = "How was dinner?"
        content.body = "A quick rating helps your Auto-draft pick winners next time."
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let req = UNNotificationRequest(identifier: nightlyRatingId, content: content, trigger: trigger)
        center.add(req)
    }

    static func cancelNightlyRating() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [nightlyRatingId])
    }
}
