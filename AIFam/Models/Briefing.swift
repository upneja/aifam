import Foundation

struct Briefing: Sendable {
    let greeting: String
    let summary: String
    let items: [BriefingItem]
    let stats: BriefingStats
    let generatedAt: Date
}

struct BriefingItem: Identifiable, Sendable {
    let id: UUID
    let text: String
    let category: BinderCategory
    let priority: InsightPriority
    let actionSuggestion: String?

    init(
        text: String,
        category: BinderCategory,
        priority: InsightPriority,
        actionSuggestion: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.category = category
        self.priority = priority
        self.actionSuggestion = actionSuggestion
    }
}

struct BriefingStats: Sendable {
    let eventsToday: Int
    let tasksDue: Int
    let upcomingDates: Int
    let sleepHours: Double?
    let stepsToday: Int?
}
