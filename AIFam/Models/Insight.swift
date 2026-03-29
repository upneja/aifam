import Foundation

enum InsightPriority: Int, Comparable, Sendable {
    case critical = 0  // Today or overdue
    case high = 1      // Within 3 days
    case medium = 2    // Within 7 days
    case low = 3       // Informational

    static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum InsightType: String, Sendable {
    case calendarConflict
    case upcomingBirthday
    case overdueTask
    case upcomingDeadline
    case sleepQuality
    case noPlansWarning
    case busyDay
    case healthTrend
}

struct Insight: Identifiable, Sendable {
    let id: UUID
    let type: InsightType
    let priority: InsightPriority
    let title: String
    let detail: String
    let category: BinderCategory
    let relatedItemTitle: String?
    let actionSuggestion: String?
    let createdAt: Date

    init(
        type: InsightType,
        priority: InsightPriority,
        title: String,
        detail: String,
        category: BinderCategory,
        relatedItemTitle: String? = nil,
        actionSuggestion: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.priority = priority
        self.title = title
        self.detail = detail
        self.category = category
        self.relatedItemTitle = relatedItemTitle
        self.actionSuggestion = actionSuggestion
        self.createdAt = Date()
    }
}
