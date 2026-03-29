import AppIntents

struct AIFamShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MorningBriefingIntent(),
            phrases: [
                "Morning briefing from \(.applicationName)",
                "Get my briefing from \(.applicationName)",
                "What's new in \(.applicationName)",
                "\(.applicationName) briefing"
            ],
            shortTitle: "Morning Briefing",
            systemImageName: "book.closed.fill"
        )

        AppShortcut(
            intent: DayOverviewIntent(),
            phrases: [
                "What's my day look like in \(.applicationName)",
                "Show my schedule from \(.applicationName)",
                "What do I have today \(.applicationName)",
                "\(.applicationName) day overview"
            ],
            shortTitle: "Day Overview",
            systemImageName: "calendar"
        )
    }
}
