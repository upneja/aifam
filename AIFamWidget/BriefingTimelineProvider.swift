import WidgetKit

struct BriefingEntry: TimelineEntry {
    let date: Date
    let briefing: SharedBriefingData?
}

struct BriefingTimelineProvider: TimelineProvider {
    private let sharedDataManager = SharedDataManager()

    func placeholder(in context: Context) -> BriefingEntry {
        BriefingEntry(
            date: Date(),
            briefing: SharedBriefingData(
                greeting: "Good morning. Here's your briefing.",
                summary: "3 items need your attention today.",
                items: [
                    SharedBriefingItem(text: "Sarah's Birthday — in 4 days", category: "dates", priority: 1),
                    SharedBriefingItem(text: "Team standup conflicts with dentist", category: "calendar", priority: 0),
                    SharedBriefingItem(text: "Lease renewal — due in 22 days", category: "tasks", priority: 2),
                ],
                eventsToday: 4,
                tasksDue: 2,
                upcomingDates: 3,
                sleepHours: 7.2,
                generatedAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BriefingEntry) -> Void) {
        let briefing = sharedDataManager.loadBriefing()
        completion(BriefingEntry(date: Date(), briefing: briefing))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BriefingEntry>) -> Void) {
        let briefing = sharedDataManager.loadBriefing()
        let entry = BriefingEntry(date: Date(), briefing: briefing)

        // Refresh every 20 minutes (~40-70 refreshes per day within system budget)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 20, to: Date())!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
