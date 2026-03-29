import Foundation
import SwiftData

@Observable
final class InsightEngine {
    var insights: [Insight] = []
    var lastGeneratedAt: Date?

    private let healthService: HealthIngestionService

    @MainActor
    init(healthService: HealthIngestionService = HealthIngestionService()) {
        self.healthService = healthService
    }

    // MARK: - Generate All Insights

    @MainActor
    func generateInsights(modelContext: ModelContext) async {
        var newInsights: [Insight] = []

        let allItems = fetchAllItems(modelContext: modelContext)

        newInsights.append(contentsOf: detectCalendarConflicts(items: allItems))
        newInsights.append(contentsOf: detectUpcomingBirthdays(items: allItems))
        newInsights.append(contentsOf: detectOverdueTasks(items: allItems))
        newInsights.append(contentsOf: detectUpcomingDeadlines(items: allItems))
        newInsights.append(contentsOf: detectBusyDays(items: allItems))
        newInsights.append(contentsOf: detectNoPlanWarnings(items: allItems))
        newInsights.append(contentsOf: await detectSleepQuality())

        // Sort by priority (critical first), then by creation date
        insights = newInsights.sorted { a, b in
            if a.priority != b.priority { return a.priority < b.priority }
            return a.createdAt < b.createdAt
        }

        lastGeneratedAt = Date()
    }

    // MARK: - Fetch Items

    private func fetchAllItems(modelContext: ModelContext) -> [BinderItem] {
        let descriptor = FetchDescriptor<BinderItem>(
            predicate: #Predicate<BinderItem> { !$0.isCompleted }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Calendar Conflicts

    private func detectCalendarConflicts(items: [BinderItem]) -> [Insight] {
        let calendarItems = items.filter { $0.category == .calendar }

        return calendarItems
            .filter { $0.title.hasPrefix("Conflict:") }
            .map { item in
                Insight(
                    type: .calendarConflict,
                    priority: .critical,
                    title: item.title,
                    detail: item.detail,
                    category: .calendar,
                    relatedItemTitle: item.title,
                    actionSuggestion: "Reschedule one of these events"
                )
            }
    }

    // MARK: - Upcoming Birthdays

    private func detectUpcomingBirthdays(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        return items
            .filter { $0.category == .dates && $0.title.lowercased().contains("birthday") }
            .compactMap { item -> Insight? in
                guard let dueDate = item.dueDate else { return nil }
                let daysUntil = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 999
                guard daysUntil >= 0 && daysUntil <= 14 else { return nil }

                let priority: InsightPriority
                if daysUntil <= 1 { priority = .critical }
                else if daysUntil <= 3 { priority = .high }
                else if daysUntil <= 7 { priority = .medium }
                else { priority = .low }

                let hasPlans = !item.relatedNotes.isEmpty &&
                    !item.relatedNotes.contains("No gift or plan yet")

                let action = hasPlans ? nil : "No plans yet — want me to help?"

                return Insight(
                    type: .upcomingBirthday,
                    priority: priority,
                    title: item.title,
                    detail: daysUntil == 0 ? "Today!" : daysUntil == 1 ? "Tomorrow" : "In \(daysUntil) days",
                    category: .dates,
                    relatedItemTitle: item.title,
                    actionSuggestion: action
                )
            }
    }

    // MARK: - Overdue Tasks

    private func detectOverdueTasks(items: [BinderItem]) -> [Insight] {
        let now = Date()

        return items
            .filter { $0.category == .tasks }
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                return dueDate < now
            }
            .map { item in
                let calendar = Calendar.current
                let daysOverdue = calendar.dateComponents([.day], from: item.dueDate!, to: now).day ?? 0

                return Insight(
                    type: .overdueTask,
                    priority: .critical,
                    title: "Overdue: \(item.title)",
                    detail: daysOverdue == 1 ? "1 day overdue" : "\(daysOverdue) days overdue",
                    category: .tasks,
                    relatedItemTitle: item.title,
                    actionSuggestion: "Complete or reschedule this task"
                )
            }
    }

    // MARK: - Upcoming Deadlines

    private func detectUpcomingDeadlines(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        return items
            .filter { $0.category == .tasks && $0.dueDate != nil }
            .compactMap { item -> Insight? in
                let daysUntil = calendar.dateComponents([.day], from: now, to: item.dueDate!).day ?? 999
                guard daysUntil >= 0 && daysUntil <= 3 else { return nil }

                return Insight(
                    type: .upcomingDeadline,
                    priority: daysUntil == 0 ? .critical : .high,
                    title: item.title,
                    detail: daysUntil == 0 ? "Due today" : "Due in \(daysUntil) day\(daysUntil == 1 ? "" : "s")",
                    category: .tasks,
                    relatedItemTitle: item.title,
                    actionSuggestion: nil
                )
            }
    }

    // MARK: - Busy Day Detection

    private func detectBusyDays(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        // Group today's calendar items
        let todayItems = items.filter { item in
            guard item.category == .calendar, let dueDate = item.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: now)
        }

        guard todayItems.count >= 4 else { return [] }

        return [Insight(
            type: .busyDay,
            priority: .medium,
            title: "Busy day ahead",
            detail: "\(todayItems.count) events scheduled today",
            category: .calendar,
            actionSuggestion: nil
        )]
    }

    // MARK: - No Plan Warnings

    private func detectNoPlanWarnings(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        return items
            .filter { $0.category == .dates }
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                let daysUntil = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 999
                return daysUntil >= 0 && daysUntil <= 7
            }
            .filter { $0.relatedNotes.contains("No gift or plan yet") }
            .map { item in
                Insight(
                    type: .noPlansWarning,
                    priority: .high,
                    title: "No plans for \(item.title)",
                    detail: "Coming up soon with nothing arranged",
                    category: .dates,
                    relatedItemTitle: item.title,
                    actionSuggestion: "Want me to help plan something?"
                )
            }
    }

    // MARK: - Sleep Quality

    @MainActor
    private func detectSleepQuality() async -> [Insight] {
        guard let sleep = await healthService.fetchLastNightSleep() else { return [] }

        let hours = Int(sleep.totalMinutes) / 60
        let mins = Int(sleep.totalMinutes) % 60

        let priority: InsightPriority
        let suggestion: String?

        switch sleep.quality {
        case .good:
            priority = .low
            suggestion = nil
        case .fair:
            priority = .medium
            suggestion = "Consider an earlier bedtime tonight"
        case .poor:
            priority = .high
            suggestion = "You might want to take it easy today"
        }

        return [Insight(
            type: .sleepQuality,
            priority: priority,
            title: "Last night: \(hours)h \(mins)m — \(sleep.quality.displayName)",
            detail: sleepBreakdown(sleep),
            category: .notes,
            actionSuggestion: suggestion
        )]
    }

    private func sleepBreakdown(_ sleep: SleepSummary) -> String {
        var parts: [String] = []
        if sleep.deepMinutes > 0 {
            parts.append("\(Int(sleep.deepMinutes))m deep")
        }
        if sleep.remMinutes > 0 {
            parts.append("\(Int(sleep.remMinutes))m REM")
        }
        if sleep.awakeMinutes > 0 {
            parts.append("\(Int(sleep.awakeMinutes))m awake")
        }
        return parts.isEmpty ? "No stage data" : parts.joined(separator: " · ")
    }
}
