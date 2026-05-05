import Foundation
import UserNotifications

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    /// Returns true when the user has granted (or has yet to be asked for)
    /// notification permission. Records the latest known status so views can
    /// decide whether to show a "re-enable in Settings" CTA without each one
    /// hitting the UN center directly.
    @MainActor
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings().authorizationStatus
        // If the user previously denied, requesting again silently no-ops at
        // the OS level. The caller (Settings/More) is expected to surface a
        // "Open iOS Settings" CTA instead. Keep this method idempotent so it
        // can still be called from cold-launch wiring without re-prompting.
        if current == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    /// Schedules a repeating Sunday 8pm local-time notification prompting
    /// Elisa to log weekly Best Of entries. Tapping the notification
    /// deep-links into WeeklyBestOfInputView via AppDelegate's didReceive handler.
    /// Safe to call on every app launch — UNUserNotificationCenter dedupes on identifier.
    func scheduleWeeklyBestOfPrompt() async {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Best Of"
        content.body  = "Any highlights from the week? Best bites, moments, funny stuff..."
        content.sound = .default
        content.userInfo = ["destination": "weekly-bestof"]

        var comps = DateComponents()
        comps.weekday = 1   // Sunday
        comps.hour    = 20
        comps.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "miracles-weekly-bestof",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Fires a test notification in 5 seconds using the real notification format.
    func sendTestNotification() async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Today in Miracles"
        content.body  = "✨ Met at Cliffs of ID — 2025"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "miracles-test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    /// Safety-net: schedules 9am notifications for the next 30 days using DailySetupService.selectEntry.
    /// Provides coverage for days the app is never opened and the 12:01am trigger doesn't run.
    /// DailySetupService.runDailySetup() overwrites today's notification with fresher data when it runs.
    func scheduleOnThisDay(allEntries: [BestOfEntry]) async {
        let center = UNUserNotificationCenter.current()

        // Clear existing 30-day schedule
        let pending  = await center.pendingNotificationRequests()
        let toRemove = pending
            .filter { $0.identifier.hasPrefix("miracles-otd-") || $0.identifier.hasPrefix("miracles-fallback-") }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: toRemove)

        let cal = Calendar.current

        for daysAhead in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: daysAhead, to: Date()) else { continue }

            // Delegate to the single source of truth
            guard let entry = DailySetupService.shared.selectEntry(for: date, from: allEntries) else { continue }

            var comps      = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour     = 9
            comps.minute   = 0

            let trigger    = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content    = UNMutableNotificationContent()
            content.title  = "Today in Miracles"
            content.body   = "\(entry.category.emoji) \(entry.entry) — \(entry.year)"
            content.sound  = .default

            let dateKey = DailySetupService.shared.dateString(for: date)
            let request = UNNotificationRequest(
                identifier: "miracles-fallback-\(dateKey)",
                content:    content,
                trigger:    trigger
            )
            try? await center.add(request)
        }
    }
}
