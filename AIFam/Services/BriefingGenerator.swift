import Foundation
import SwiftData

@Observable
final class BriefingGenerator {
    var currentBriefing: Briefing?
    var isGenerating = false

    private let insightEngine: InsightEngine

    @MainActor
    init(insightEngine: InsightEngine = InsightEngine()) {
        self.insightEngine = insightEngine
    }

    // MARK: - Generate Briefing

    @MainActor
    func generateBriefing(
        tone: TonePreset,
        modelContext: ModelContext
    ) async -> Briefing {
        isGenerating = true
        defer { isGenerating = false }

        // Generate fresh insights
        await insightEngine.generateInsights(modelContext: modelContext)

        let allItems = fetchAllItems(modelContext: modelContext)
        let stats = computeStats(items: allItems)

        // Build greeting
        let greeting = buildGreeting(tone: tone)

        // Build summary line
        let summary = buildSummary(
            tone: tone,
            insights: insightEngine.insights,
            stats: stats
        )

        // Map insights to briefing items
        let briefingItems = insightEngine.insights.prefix(8).map { insight in
            BriefingItem(
                text: formatInsight(insight, tone: tone),
                category: insight.category,
                priority: insight.priority,
                actionSuggestion: insight.actionSuggestion
            )
        }

        let briefing = Briefing(
            greeting: greeting,
            summary: summary,
            items: Array(briefingItems),
            stats: stats,
            generatedAt: Date()
        )

        currentBriefing = briefing
        return briefing
    }

    // MARK: - Greeting

    private func buildGreeting(tone: TonePreset) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 0..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        default: timeOfDay = "evening"
        }

        switch tone {
        case .casual:
            switch timeOfDay {
            case "morning": return "morning! here's your rundown."
            case "afternoon": return "hey — quick afternoon check-in."
            default: return "evening. here's where things stand."
            }
        case .standard:
            switch timeOfDay {
            case "morning": return "Good morning. Here's your briefing."
            case "afternoon": return "Good afternoon. Here's what's on your radar."
            default: return "Good evening. Here's your update."
            }
        case .professional:
            switch timeOfDay {
            case "morning": return "Good morning. Your daily briefing is ready."
            case "afternoon": return "Good afternoon. Please review today's items."
            default: return "Good evening. Here is your status update."
            }
        }
    }

    // MARK: - Summary Line

    private func buildSummary(
        tone: TonePreset,
        insights: [Insight],
        stats: BriefingStats
    ) -> String {
        let criticalCount = insights.filter { $0.priority == .critical }.count
        let highCount = insights.filter { $0.priority == .high }.count

        if criticalCount > 0 {
            switch tone {
            case .casual:
                return "heads up — \(criticalCount) thing\(criticalCount == 1 ? "" : "s") need your attention right now."
            case .standard:
                return "\(criticalCount) item\(criticalCount == 1 ? " needs" : "s need") your attention today."
            case .professional:
                return "There \(criticalCount == 1 ? "is" : "are") \(criticalCount) critical item\(criticalCount == 1 ? "" : "s") requiring immediate attention."
            }
        } else if highCount > 0 {
            switch tone {
            case .casual:
                return "nothing urgent, but \(highCount) thing\(highCount == 1 ? "" : "s") coming up soon."
            case .standard:
                return "\(highCount) thing\(highCount == 1 ? "" : "s") coming up that \(highCount == 1 ? "needs" : "need") a look."
            case .professional:
                return "\(highCount) item\(highCount == 1 ? "" : "s") of note approaching. No immediate action required."
            }
        } else {
            switch tone {
            case .casual:
                return "you're all good — nothing pressing."
            case .standard:
                return "You're all caught up. Nothing needs attention right now."
            case .professional:
                return "No items require immediate attention. All matters are in order."
            }
        }
    }

    // MARK: - Format Individual Insight per Tone

    private func formatInsight(_ insight: Insight, tone: TonePreset) -> String {
        switch tone {
        case .casual:
            return formatCasual(insight)
        case .standard:
            return formatStandard(insight)
        case .professional:
            return formatProfessional(insight)
        }
    }

    private func formatCasual(_ insight: Insight) -> String {
        switch insight.type {
        case .calendarConflict:
            return "schedule clash — \(insight.detail)"
        case .upcomingBirthday:
            let name = insight.title.replacingOccurrences(of: "'s Birthday", with: "")
            return "\(name.lowercased())'s bday is \(insight.detail.lowercased()). \(insight.actionSuggestion?.lowercased() ?? "")"
        case .overdueTask:
            let title = insight.title.replacingOccurrences(of: "Overdue: ", with: "")
            return "\(title.lowercased()) is overdue (\(insight.detail))"
        case .upcomingDeadline:
            return "\(insight.title.lowercased()) — \(insight.detail.lowercased())"
        case .sleepQuality:
            return "slept \(insight.title.lowercased().replacingOccurrences(of: "last night: ", with: ""))"
        case .noPlansWarning:
            return "\(insight.title.lowercased()) — might wanna get on that"
        case .busyDay:
            return "packed day — \(insight.detail.lowercased())"
        case .healthTrend:
            return insight.detail.lowercased()
        }
    }

    private func formatStandard(_ insight: Insight) -> String {
        switch insight.type {
        case .calendarConflict:
            return "Schedule conflict: \(insight.detail)"
        case .upcomingBirthday:
            return "\(insight.title) — \(insight.detail). \(insight.actionSuggestion ?? "")"
        case .overdueTask:
            return "\(insight.title) (\(insight.detail))"
        case .upcomingDeadline:
            return "\(insight.title) — \(insight.detail)"
        case .sleepQuality:
            return insight.title
        case .noPlansWarning:
            return "\(insight.title) — \(insight.actionSuggestion ?? insight.detail)"
        case .busyDay:
            return "\(insight.title): \(insight.detail)"
        case .healthTrend:
            return insight.detail
        }
    }

    private func formatProfessional(_ insight: Insight) -> String {
        switch insight.type {
        case .calendarConflict:
            return "Scheduling conflict detected: \(insight.detail). Resolution recommended."
        case .upcomingBirthday:
            return "Reminder: \(insight.title). \(insight.detail). \(insight.actionSuggestion ?? "")"
        case .overdueTask:
            return "\(insight.title). Status: \(insight.detail). Action required."
        case .upcomingDeadline:
            return "Deadline: \(insight.title). \(insight.detail)."
        case .sleepQuality:
            return "Wellness note: \(insight.title)."
        case .noPlansWarning:
            return "Advisory: \(insight.title). No arrangements have been made."
        case .busyDay:
            return "Schedule advisory: \(insight.detail). Plan accordingly."
        case .healthTrend:
            return "Health observation: \(insight.detail)."
        }
    }

    // MARK: - Stats

    private func computeStats(items: [BinderItem]) -> BriefingStats {
        let calendar = Calendar.current
        let now = Date()

        let eventsToday = items.filter { item in
            item.category == .calendar &&
            item.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        }.count

        let tasksDue = items.filter { item in
            item.category == .tasks &&
            item.dueDate.map { $0 <= calendar.date(byAdding: .day, value: 3, to: now)! } ?? false
        }.count

        let upcomingDates = items.filter { item in
            item.category == .dates &&
            item.dueDate.map { $0 >= now && $0 <= calendar.date(byAdding: .day, value: 14, to: now)! } ?? false
        }.count

        let sleepHours = insightEngine.insights
            .first { $0.type == .sleepQuality }
            .flatMap { insight -> Double? in
                // Parse from title "Last night: Xh Ym"
                let pattern = /(\d+)h\s*(\d+)m/
                guard let match = insight.title.firstMatch(of: pattern) else { return nil }
                let hours = Double(match.1) ?? 0
                let mins = Double(match.2) ?? 0
                return hours + mins / 60.0
            }

        return BriefingStats(
            eventsToday: eventsToday,
            tasksDue: tasksDue,
            upcomingDates: upcomingDates,
            sleepHours: sleepHours,
            stepsToday: nil // Populated by HealthIngestionService separately
        )
    }

    // MARK: - Helpers

    private func fetchAllItems(modelContext: ModelContext) -> [BinderItem] {
        let descriptor = FetchDescriptor<BinderItem>(
            predicate: #Predicate<BinderItem> { !$0.isCompleted }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
