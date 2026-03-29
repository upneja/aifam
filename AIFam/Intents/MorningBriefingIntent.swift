import AppIntents
import SwiftUI

struct MorningBriefingIntent: AppIntent {
    static let title: LocalizedStringResource = "Morning Briefing"
    static let description: IntentDescription = "Get your morning briefing from your secretary."
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let briefing = SharedDataManager().loadBriefing()

        guard let briefing else {
            return .result(
                dialog: "I don't have a briefing ready yet. Open AI Fam to get started."
            ) {
                EmptyBriefingSnippetView()
            }
        }

        let spokenText = buildSpokenBriefing(briefing)

        return .result(dialog: "\(spokenText)") {
            SiriBriefingSnippetView(briefing: briefing)
        }
    }

    private func buildSpokenBriefing(_ briefing: SharedBriefingData) -> String {
        var parts: [String] = []
        parts.append(briefing.greeting)
        parts.append(briefing.summary)

        for item in briefing.items.prefix(3) {
            parts.append(item.text)
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Snippet Views

struct SiriBriefingSnippetView: View {
    let briefing: SharedBriefingData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(briefing.greeting)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.72, green: 0.59, blue: 0.31))

            ForEach(briefing.items.prefix(3)) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(categoryColor(item.categoryRaw))
                        .frame(width: 6, height: 6)

                    Text(item.text)
                        .font(.system(size: 13))
                        .lineLimit(2)
                }
            }

            HStack(spacing: 16) {
                Label("\(briefing.eventsToday) events", systemImage: "calendar")
                Label("\(briefing.tasksDue) due", systemImage: "checklist")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func categoryColor(_ raw: String) -> Color {
        switch raw {
        case "calendar": Color(red: 0.20, green: 0.66, blue: 0.33)
        case "tasks": Color(red: 0.79, green: 0.53, blue: 0.04)
        case "dates": Color(red: 0.84, green: 0.19, blue: 0.19)
        case "notes": Color(red: 0.49, green: 0.23, blue: 0.93)
        default: Color.gray
        }
    }
}

struct EmptyBriefingSnippetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 0.72, green: 0.59, blue: 0.31))

            Text("Open AI Fam to build your first briefing")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
