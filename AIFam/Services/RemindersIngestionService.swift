import EventKit
import Foundation

struct ReminderData: Sendable {
    let calendarItemIdentifier: String
    let title: String
    let listName: String
    let dueDate: Date?
    let isCompleted: Bool
    let completionDate: Date?
    let priority: Int
    let notes: String?
    let creationDate: Date?
}

@Observable
@MainActor
final class RemindersIngestionService {
    private let eventStore = EKEventStore()

    var reminderCount: Int = 0
    var overdueCount: Int = 0
    var lastSyncDate: Date?

    // MARK: - Fetch All Reminders

    func fetchReminders() async -> [ReminderData] {
        let calendars = eventStore.calendars(for: .reminder)
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForReminders(in: calendars)

        let mapped: [ReminderData] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let data = (reminders ?? []).map { reminder in
                    ReminderData(
                        calendarItemIdentifier: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled",
                        listName: reminder.calendar.title,
                        dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                        isCompleted: reminder.isCompleted,
                        completionDate: reminder.completionDate,
                        priority: reminder.priority,
                        notes: reminder.notes,
                        creationDate: reminder.creationDate
                    )
                }
                continuation.resume(returning: data)
            }
        }

        reminderCount = mapped.count
        overdueCount = mapped.filter { isOverdue($0) }.count
        lastSyncDate = Date()

        return mapped
    }

    // MARK: - Fetch Incomplete Reminders

    func fetchIncompleteReminders() async -> [ReminderData] {
        let calendars = eventStore.calendars(for: .reminder)
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let data = (reminders ?? []).map { reminder in
                    ReminderData(
                        calendarItemIdentifier: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled",
                        listName: reminder.calendar.title,
                        dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                        isCompleted: false,
                        completionDate: nil,
                        priority: reminder.priority,
                        notes: reminder.notes,
                        creationDate: reminder.creationDate
                    )
                }
                continuation.resume(returning: data)
            }
        }
    }

    // MARK: - Fetch Reminder Lists

    func fetchReminderLists() -> [(name: String, count: Int)] {
        let calendars = eventStore.calendars(for: .reminder)
        return calendars.map { calendar in
            // Count populated after async fetch
            return (name: calendar.title, count: 0)
        }
    }

    // MARK: - Completion Rate

    func completionRate(for reminders: [ReminderData]) -> Double {
        guard !reminders.isEmpty else { return 0 }
        let completed = reminders.filter { $0.isCompleted }.count
        return Double(completed) / Double(reminders.count)
    }

    // MARK: - Map to BinderItems

    func mapToBinderItems(reminders: [ReminderData]) -> [BinderItem] {
        let now = Date()
        let calendar = Calendar.current

        let incomplete = reminders.filter { !$0.isCompleted }
            .sorted { sortPriority($0, $1, now: now) }

        return incomplete.map { reminder in
            let daysUntil: Int?
            if let dueDate = reminder.dueDate {
                daysUntil = calendar.dateComponents([.day], from: now, to: dueDate).day
            } else {
                daysUntil = nil
            }

            let overdue = isOverdue(reminder)
            let detailParts: [String] = [
                reminder.listName,
                reminder.dueDate.map { formatDueDate($0) },
                overdue ? "OVERDUE" : nil,
                priorityLabel(reminder.priority)
            ].compactMap { $0 }

            return BinderItem(
                title: reminder.title,
                detail: detailParts.joined(separator: " · "),
                category: .tasks,
                dueDate: reminder.dueDate,
                urgencyDays: daysUntil,
                relatedNotes: reminder.notes.map { [$0] } ?? [],
                source: "reminders"
            )
        }
    }

    // MARK: - Helpers

    private func isOverdue(_ reminder: ReminderData) -> Bool {
        guard !reminder.isCompleted, let dueDate = reminder.dueDate else { return false }
        return dueDate < Date()
    }

    private func sortPriority(_ a: ReminderData, _ b: ReminderData, now: Date) -> Bool {
        // Overdue first, then by due date, then by priority
        let aOverdue = isOverdue(a)
        let bOverdue = isOverdue(b)
        if aOverdue != bOverdue { return aOverdue }
        if let aDate = a.dueDate, let bDate = b.dueDate { return aDate < bDate }
        if a.dueDate != nil { return true }
        if b.dueDate != nil { return false }
        return a.priority > b.priority
    }

    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Due \(formatter.string(from: date))"
    }

    private func priorityLabel(_ priority: Int) -> String? {
        switch priority {
        case 1: "High priority"
        case 5: "Medium priority"
        case 9: "Low priority"
        default: nil
        }
    }
}
