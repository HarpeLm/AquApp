import Foundation
import UserNotifications

/// Programme les rappels d'hydratation. Ne touche qu'aux notifications préfixées
/// `aquapp_reminder_` : minuit, canicule et annonce Premium restent intactes.
enum ReminderScheduler {
    static let idPrefix = "aquapp_reminder_"

    static let startHourKey = "notifStartHour"
    static let endHourKey = "notifEndHour"
    static let intervalKey = "notifIntervalHour"
    static let enabledKey = "notificationsOn"

    static var startHour: Int { UserDefaults.standard.object(forKey: startHourKey) as? Int ?? 8 }
    static var endHour: Int { UserDefaults.standard.object(forKey: endHourKey) as? Int ?? 22 }
    static var intervalHours: Int { max(1, UserDefaults.standard.object(forKey: intervalKey) as? Int ?? 2) }

    /// Heures de rappel entre `start` et `end` inclus.
    static func hours(start: Int, end: Int, interval: Int) -> [Int] {
        guard interval > 0, start <= end else { return [] }
        return Array(stride(from: start, through: end, by: interval))
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(start: Int, end: Int, interval: Int) async {
        await cancelAll()
        let messages = L10n.notifReminderMessages
        for (index, hour) in hours(start: start, end: end, interval: interval).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notif.reminder_title")
            content.body = messages[index % messages.count]
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
            try? await UNUserNotificationCenter.current()
                .add(UNNotificationRequest(identifier: "\(idPrefix)\(hour)", content: content, trigger: trigger))
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
