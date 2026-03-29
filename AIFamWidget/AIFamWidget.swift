import SwiftUI
import WidgetKit

struct AIFamWidget: Widget {
    let kind: String = "AIFamBriefingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BriefingTimelineProvider()) { entry in
            BriefingWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Briefing")
        .description("Your secretary's morning briefing at a glance.")
        .supportedFamilies([.systemMedium])
    }
}
