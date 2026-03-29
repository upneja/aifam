import SwiftUI
import WidgetKit

struct BriefingWidgetView: View {
    let entry: BriefingEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if let briefing = entry.briefing {
            VStack(alignment: .leading, spacing: 8) {
                // Greeting
                Text(briefing.greeting)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.59, blue: 0.31)) // AppColors.gold
                    .lineLimit(1)

                // Top items
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(briefing.items.prefix(3)) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(categoryColor(item.categoryRaw))
                                .frame(width: 6, height: 6)

                            Text(item.text)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Stats row
                HStack(spacing: 12) {
                    statPill(icon: "calendar", value: "\(briefing.eventsToday)", label: "events")
                    statPill(icon: "checklist", value: "\(briefing.tasksDue)", label: "due")
                    if let sleep = briefing.sleepHours {
                        statPill(icon: "moon.fill", value: String(format: "%.1f", sleep), label: "hrs")
                    }
                }
            }
            .padding(14)
            .containerBackground(for: .widget) {
                Color(uiColor: .systemBackground)
            }
        } else {
            emptyView
        }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
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

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color(red: 0.72, green: 0.59, blue: 0.31))

            Text("Open AI Fam to get started")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}
