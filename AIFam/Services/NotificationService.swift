import UserNotifications
import Foundation

enum NotificationCategory: String {
    case morningBriefing = "MORNING_BRIEFING"
    case conflictAlert = "CONFLICT_ALERT"
    case birthdayReminder = "BIRTHDAY_REMINDER"
    case taskOverdue = "TASK_OVERDUE"
}

@Observable
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Setup

    func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_BINDER",
            title: "Open Binder",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Got it",
            options: [.destructive]
        )

        let briefingCategory = UNNotificationCategory(
            identifier: NotificationCategory.morningBriefing.rawValue,
            actions: [openAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let conflictCategory = UNNotificationCategory(
            identifier: NotificationCategory.conflictAlert.rawValue,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        let birthdayCategory = UNNotificationCategory(
            identifier: NotificationCategory.birthdayReminder.rawValue,
            actions: [openAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let taskCategory = UNNotificationCategory(
            identifier: NotificationCategory.taskOverdue.rawValue,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            briefingCategory,
            conflictCategory,
            birthdayCategory,
            taskCategory
        ])
    }

    // MARK: - Schedule Morning Briefing

    func scheduleMorningBriefing(briefing: SharedBriefingData) {
        // Remove existing morning briefing notifications
        center.removePendingNotificationRequests(withIdentifiers: ["morning-briefing"])

        let content = UNMutableNotificationContent()
        content.title = briefing.greeting
        content.body = briefing.summary

        if let topItem = briefing.items.first {
            content.body += " " + topItem.text
        }

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.morningBriefing.rawValue
        content.threadIdentifier = "briefing"

        // Schedule for tomorrow at 7:30 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "morning-briefing",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule Conflict Alert

    func scheduleConflictAlert(
        event1: String,
        event2: String,
        conflictDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Conflict"
        content.body = "\(event1) overlaps with \(event2). You may need to reschedule."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.conflictAlert.rawValue
        content.threadIdentifier = "alerts"

        // Notify 1 hour before the conflict
        let triggerDate = conflictDate.addingTimeInterval(-3600)
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "conflict-\(event1.hashValue)-\(event2.hashValue)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule Birthday Reminder

    func scheduleBirthdayReminder(
        name: String,
        birthdayDate: Date,
        daysBeforeReminder: Int = 3
    ) {
        let content = UNMutableNotificationContent()
        content.title = "\(name)'s Birthday Coming Up"

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateStr = formatter.string(from: birthdayDate)

        if daysBeforeReminder == 0 {
            content.body = "\(name)'s birthday is today! Don't forget to wish them well."
        } else if daysBeforeReminder == 1 {
            content.body = "\(name)'s birthday is tomorrow (\(dateStr))."
        } else {
            content.body = "\(name)'s birthday is in \(daysBeforeReminder) days (\(dateStr)). Time to plan?"
        }

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.birthdayReminder.rawValue
        content.threadIdentifier = "birthdays"

        guard let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBeforeReminder,
            to: birthdayDate
        ) else { return }

        // Notify at 9 AM on the reminder day
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: reminderDate
        )
        components.hour = 9
        components.minute = 0

        guard let triggerDate = Calendar.current.date(from: components),
              triggerDate > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let identifier = "birthday-\(name.hashValue)-\(daysBeforeReminder)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule Overdue Task Alert

    func scheduleTaskOverdueAlert(taskTitle: String, dueDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Task Overdue"
        content.body = "\"\(taskTitle)\" was due and hasn't been completed."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.taskOverdue.rawValue
        content.threadIdentifier = "tasks"

        // Notify 1 hour after due date
        let triggerDate = dueDate.addingTimeInterval(3600)
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "overdue-\(taskTitle.hashValue)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule from Briefing Data

    func scheduleFromBriefing(_ briefing: SharedBriefingData) {
        // Schedule the recurring morning briefing
        scheduleMorningBriefing(briefing: briefing)

        // Schedule birthday reminders from items with "dates" category
        for item in briefing.items where item.categoryRaw == "dates" {
            let daysUntil = parseDaysUntil(item.text)
            scheduleBirthdayReminder(
                name: item.text.components(separatedBy: " — ").first ?? item.text,
                birthdayDate: Date().addingTimeInterval(TimeInterval(daysUntil * 86400)),
                daysBeforeReminder: min(daysUntil, 3)
            )
        }
    }

    // MARK: - Remove All

    func removeAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    private func parseDaysUntil(_ detail: String) -> Int {
        if detail.lowercased().contains("today") { return 0 }
        if detail.lowercased().contains("tomorrow") { return 1 }

        let pattern = /[Ii]n (\d+) days?/
        if let match = detail.firstMatch(of: pattern), let days = Int(match.1) {
            return days
        }

        return 7 // Default fallback
    }
}
