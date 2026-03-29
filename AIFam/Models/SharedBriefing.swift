import Foundation

struct SharedBriefingData: Codable, Sendable {
    let greeting: String
    let summary: String
    let items: [SharedBriefingItem]
    let eventsToday: Int
    let tasksDue: Int
    let upcomingDates: Int
    let sleepHours: Double?
    let generatedAt: Date
}

struct SharedBriefingItem: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let categoryRaw: String
    let priorityRaw: Int

    init(id: UUID = UUID(), text: String, category: String, priority: Int) {
        self.id = id
        self.text = text
        self.categoryRaw = category
        self.priorityRaw = priority
    }
}

enum SharedDataKeys {
    static let appGroupID = "group.com.tabbyapp.shared"
    static let briefingKey = "latestBriefing"
}
