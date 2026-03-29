import AppIntents
import SwiftUI

struct DayOverviewIntent: AppIntent {
    static let title: LocalizedStringResource = "What's My Day Look Like"
    static let description: IntentDescription = "Get a quick overview of your day ahead."
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let briefing = SharedDataManager().loadBriefing()

        guard let briefing else {
            return .result(
                dialog: "I don't have your schedule loaded yet. Open AI Fam to get started."
            ) {
                EmptyBriefingSnippetView()
            }
        }

        let eventsToday = briefing.eventsToday
        let tasksDue = briefing.tasksDue

        let spoken: String
        if eventsToday == 0 && tasksDue == 0 {
            spoken = "Your day is clear. No events or tasks due today."
        } else {
            var parts: [String] = []
            if eventsToday > 0 {
                parts.append("You have \(eventsToday) event\(eventsToday == 1 ? "" : "s") today.")
            }
            if tasksDue > 0 {
                parts.append("\(tasksDue) task\(tasksDue == 1 ? "" : "s") due soon.")
            }

            let calendarItems = briefing.items.filter { $0.categoryRaw == "calendar" }
            for item in calendarItems.prefix(2) {
                parts.append(item.text)
            }

            spoken = parts.joined(separator: " ")
        }

        return .result(dialog: "\(spoken)") {
            DayOverviewSnippetView(briefing: briefing)
        }
    }
}

struct DayOverviewSnippetView: View {
    let briefing: SharedBriefingData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Schedule")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.72, green: 0.59, blue: 0.31))

            let calendarItems = briefing.items.filter { $0.categoryRaw == "calendar" }

            if calendarItems.isEmpty {
                Text("No events today — your schedule is clear.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(calendarItems.prefix(4)) { item in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(red: 0.20, green: 0.66, blue: 0.33))
                            .frame(width: 3, height: 16)

                        Text(item.text)
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                }
            }

            // Tasks due
            let taskItems = briefing.items.filter { $0.categoryRaw == "tasks" }
            if !taskItems.isEmpty {
                Divider()
                Text("\(taskItems.count) task\(taskItems.count == 1 ? "" : "s") due")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
