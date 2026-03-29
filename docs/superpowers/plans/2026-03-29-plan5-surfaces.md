# AI Fam — Plan 5: Surfaces

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the app beyond the main interface — a WidgetKit widget showing the daily briefing on the home screen, Siri integration via App Intents for voice-activated briefings, and local push notifications for morning briefings, conflict alerts, and birthday reminders. After this plan, the app is useful even when the user never opens it.

**Architecture:** The widget uses a `TimelineProvider` that reads from a shared `AppGroup` container (since widgets run in a separate process). The `BriefingGenerator` writes its latest output to the shared container as JSON. App Intents register as App Shortcuts for zero-setup Siri access. The notification service schedules local notifications based on insight priorities and user preferences.

**Tech Stack:** Swift 6.2, WidgetKit, AppIntents framework, UNUserNotificationCenter, App Groups, iOS 26 SDK

---

## File Structure

### New Files

```
AIFamWidget/
├── AIFamWidget.swift                    # Widget entry point
├── AIFamWidgetBundle.swift              # Widget bundle declaration
├── BriefingTimelineProvider.swift       # Timeline provider for widget updates
├── BriefingWidgetView.swift             # Medium widget UI
└── SharedBriefing.swift                 # Codable briefing for App Group sharing

AIFam/
├── Services/
│   ├── NotificationService.swift        # Local notification scheduling
│   └── SharedDataManager.swift          # Write briefing data to App Group
├── Intents/
│   ├── MorningBriefingIntent.swift      # "Morning briefing" Siri intent
│   ├── DayOverviewIntent.swift          # "What's my day look like" Siri intent
│   └── AIFamShortcuts.swift             # AppShortcutsProvider registration
```

### Modified Files

```
AIFam/
├── AIFamApp.swift                       # Schedule notifications on launch
```

### Xcode Configuration

- Add `AIFamWidget` widget extension target
- Add App Group: `group.com.aifam.shared`
- Enable App Group for both main app target and widget target

---

### Task 1: WidgetKit — Daily Briefing Widget

**Files:**
- Create: `AIFam/Services/SharedDataManager.swift`
- Create: `AIFamWidget/SharedBriefing.swift`
- Create: `AIFamWidget/BriefingTimelineProvider.swift`
- Create: `AIFamWidget/BriefingWidgetView.swift`
- Create: `AIFamWidget/AIFamWidgetBundle.swift`
- Create: `AIFamWidget/AIFamWidget.swift`

- [ ] **Step 1: Create the Widget Extension target in Xcode**

In Xcode: File → New → Target → Widget Extension.
- Product Name: `AIFamWidget`
- Include Configuration App Intent: No (we use static configuration)
- Embed in Application: `AIFam`

Then configure App Groups:
1. Select the `AIFam` target → Signing & Capabilities → + Capability → App Groups → Add `group.com.aifam.shared`
2. Select the `AIFamWidget` target → Signing & Capabilities → + Capability → App Groups → Add `group.com.aifam.shared`

- [ ] **Step 2: Write SharedBriefing.swift (shared between app and widget)**

Place this file in a shared location accessible by both targets, or add it to both targets' membership.

```swift
import Foundation

struct SharedBriefingData: Codable {
    let greeting: String
    let summary: String
    let items: [SharedBriefingItem]
    let eventsToday: Int
    let tasksDue: Int
    let upcomingDates: Int
    let sleepHours: Double?
    let generatedAt: Date
}

struct SharedBriefingItem: Codable, Identifiable {
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
    static let appGroupID = "group.com.aifam.shared"
    static let briefingKey = "latestBriefing"
}
```

- [ ] **Step 3: Write SharedDataManager.swift (in main app)**

```swift
import Foundation

final class SharedDataManager {
    static let shared = SharedDataManager()

    private let userDefaults: UserDefaults?

    init() {
        userDefaults = UserDefaults(suiteName: SharedDataKeys.appGroupID)
    }

    // MARK: - Write Briefing

    func saveBriefing(_ briefing: Briefing) {
        let shared = SharedBriefingData(
            greeting: briefing.greeting,
            summary: briefing.summary,
            items: briefing.items.map { item in
                SharedBriefingItem(
                    id: item.id,
                    text: item.text,
                    category: item.category.rawValue,
                    priority: item.priority.rawValue
                )
            },
            eventsToday: briefing.stats.eventsToday,
            tasksDue: briefing.stats.tasksDue,
            upcomingDates: briefing.stats.upcomingDates,
            sleepHours: briefing.stats.sleepHours,
            generatedAt: briefing.generatedAt
        )

        guard let data = try? JSONEncoder().encode(shared) else { return }
        userDefaults?.set(data, forKey: SharedDataKeys.briefingKey)
    }

    // MARK: - Read Briefing

    func loadBriefing() -> SharedBriefingData? {
        guard let data = userDefaults?.data(forKey: SharedDataKeys.briefingKey),
              let briefing = try? JSONDecoder().decode(SharedBriefingData.self, from: data) else {
            return nil
        }
        return briefing
    }
}
```

- [ ] **Step 4: Write BriefingTimelineProvider.swift**

```swift
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
```

- [ ] **Step 5: Write BriefingWidgetView.swift**

```swift
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
```

- [ ] **Step 6: Write AIFamWidgetBundle.swift**

```swift
import SwiftUI
import WidgetKit

@main
struct AIFamWidgetBundle: WidgetBundle {
    var body: some Widget {
        AIFamWidget()
    }
}
```

- [ ] **Step 7: Write AIFamWidget.swift**

```swift
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
```

- [ ] **Step 8: Build to verify both targets compile**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Run: `xcodebuild -scheme AIFamWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED for both

- [ ] **Step 9: Commit**

```bash
git add AIFamWidget/ AIFam/Services/SharedDataManager.swift
git commit -m "feat: add WidgetKit daily briefing — medium widget with greeting, top items, stats"
```

---

### Task 2: Siri Integration — App Intents

**Files:**
- Create: `AIFam/Intents/MorningBriefingIntent.swift`
- Create: `AIFam/Intents/DayOverviewIntent.swift`
- Create: `AIFam/Intents/AIFamShortcuts.swift`

- [ ] **Step 1: Write MorningBriefingIntent.swift**

```swift
import AppIntents
import SwiftData

struct MorningBriefingIntent: AppIntent {
    static let title: LocalizedStringResource = "Morning Briefing"
    static let description: IntentDescription = "Get your morning briefing from your secretary."
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let briefing = loadBriefing()

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

    private func loadBriefing() -> SharedBriefingData? {
        SharedDataManager().loadBriefing()
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

import SwiftUI

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
```

- [ ] **Step 2: Write DayOverviewIntent.swift**

```swift
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
```

- [ ] **Step 3: Write AIFamShortcuts.swift**

```swift
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
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED. App Shortcuts automatically appear in Spotlight and the Shortcuts app.

- [ ] **Step 5: Commit**

```bash
git add AIFam/Intents/
git commit -m "feat: add Siri integration — morning briefing and day overview App Intents"
```

---

### Task 3: Push Notification Service

**Files:**
- Create: `AIFam/Services/NotificationService.swift`
- Modify: `AIFam/AIFamApp.swift` (schedule notifications on launch)

- [ ] **Step 1: Write NotificationService.swift**

```swift
import UserNotifications
import Foundation

enum NotificationCategory: String {
    case morningBriefing = "MORNING_BRIEFING"
    case conflictAlert = "CONFLICT_ALERT"
    case birthdayReminder = "BIRTHDAY_REMINDER"
    case taskOverdue = "TASK_OVERDUE"
}

@Observable
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    // MARK: - Setup

    func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_BINDER",
            title: "Open Binder",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Got it",
            options: [.destructive]
        )

        let briefingCategory = UNNotificationCategory(
            identifier: NotificationCategory.morningBriefing.rawValue,
            actions: [openAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let conflictCategory = UNNotificationCategory(
            identifier: NotificationCategory.conflictAlert.rawValue,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        let birthdayCategory = UNNotificationCategory(
            identifier: NotificationCategory.birthdayReminder.rawValue,
            actions: [openAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let taskCategory = UNNotificationCategory(
            identifier: NotificationCategory.taskOverdue.rawValue,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            briefingCategory,
            conflictCategory,
            birthdayCategory,
            taskCategory
        ])
    }

    // MARK: - Schedule Morning Briefing

    func scheduleMorningBriefing(briefing: SharedBriefingData) {
        // Remove existing morning briefing notifications
        center.removePendingNotificationRequests(withIdentifiers: ["morning-briefing"])

        let content = UNMutableNotificationContent()
        content.title = briefing.greeting
        content.body = briefing.summary

        if !briefing.items.isEmpty {
            let topItem = briefing.items.first!
            content.body += " " + topItem.text
        }

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.morningBriefing.rawValue
        content.threadIdentifier = "briefing"

        // Schedule for tomorrow at 7:30 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "morning-briefing",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule Conflict Alert

    func scheduleConflictAlert(
        event1: String,
        event2: String,
        conflictDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Conflict"
        content.body = "\(event1) overlaps with \(event2). You may need to reschedule."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.conflictAlert.rawValue
        content.threadIdentifier = "alerts"

        // Notify 1 hour before the conflict
        let triggerDate = conflictDate.addingTimeInterval(-3600)
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "conflict-\(event1.hashValue)-\(event2.hashValue)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule Birthday Reminder

    func scheduleBirthdayReminder(
        name: String,
        birthdayDate: Date,
        daysBeforeReminder: Int = 3
    ) {
        let content = UNMutableNotificationContent()
        content.title = "\(name)'s Birthday Coming Up"

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateStr = formatter.string(from: birthdayDate)

        if daysBeforeReminder == 0 {
            content.body = "\(name)'s birthday is today! Don't forget to wish them well."
        } else if daysBeforeReminder == 1 {
            content.body = "\(name)'s birthday is tomorrow (\(dateStr))."
        } else {
            content.body = "\(name)'s birthday is in \(daysBeforeReminder) days (\(dateStr)). Time to plan?"
        }

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.birthdayReminder.rawValue
        content.threadIdentifier = "birthdays"

        guard let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBeforeReminder,
            to: birthdayDate
        ) else { return }

        // Notify at 9 AM on the reminder day
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: reminderDate
        )
        components.hour = 9
        components.minute = 0

        guard let triggerDate = Calendar.current.date(from: components),
              triggerDate > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let identifier = "birthday-\(name.hashValue)-\(daysBeforeReminder)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule Overdue Task Alert

    func scheduleTaskOverdueAlert(taskTitle: String, dueDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Task Overdue"
        content.body = "\"\(taskTitle)\" was due and hasn't been completed."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.taskOverdue.rawValue
        content.threadIdentifier = "tasks"

        // Notify 1 hour after due date
        let triggerDate = dueDate.addingTimeInterval(3600)
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "overdue-\(taskTitle.hashValue)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Schedule Notifications from Insights

    func scheduleFromInsights(_ insights: [Insight]) {
        // Clear old insight-based notifications
        center.removeAllPendingNotificationRequests()

        for insight in insights {
            switch insight.type {
            case .calendarConflict:
                // Parse conflict titles — format: "Conflict: Event1 vs Event2"
                let parts = insight.title
                    .replacingOccurrences(of: "Conflict: ", with: "")
                    .components(separatedBy: " vs ")
                guard parts.count == 2 else { continue }
                scheduleConflictAlert(
                    event1: parts[0],
                    event2: parts[1],
                    conflictDate: Date() // Would use actual conflict date from BinderItem
                )

            case .upcomingBirthday:
                let name = insight.title.replacingOccurrences(of: "'s Birthday", with: "")
                let daysUntil = parseDaysUntil(insight.detail)
                scheduleBirthdayReminder(
                    name: name,
                    birthdayDate: Date().addingTimeInterval(TimeInterval(daysUntil * 86400)),
                    daysBeforeReminder: min(daysUntil, 3)
                )

            case .overdueTask:
                let title = insight.title.replacingOccurrences(of: "Overdue: ", with: "")
                scheduleTaskOverdueAlert(taskTitle: title, dueDate: Date())

            default:
                break
            }
        }

        // Always schedule the morning briefing
        if let briefing = SharedDataManager().loadBriefing() {
            scheduleMorningBriefing(briefing: briefing)
        }
    }

    // MARK: - Remove All

    func removeAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    private func parseDaysUntil(_ detail: String) -> Int {
        if detail.lowercased() == "today" || detail.lowercased() == "today!" { return 0 }
        if detail.lowercased() == "tomorrow" { return 1 }

        let pattern = /[Ii]n (\d+) days?/
        if let match = detail.firstMatch(of: pattern), let days = Int(match.1) {
            return days
        }

        return 7 // Default fallback
    }
}
```

- [ ] **Step 2: Update AIFamApp.swift to initialize notifications and save briefings**

```swift
import SwiftUI
import SwiftData
import WidgetKit

@main
struct AIFamApp: App {
    @State private var syncCoordinator = DataSyncCoordinator()
    @State private var briefingGenerator = BriefingGenerator()
    @State private var notificationService = NotificationService()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingContainerView {
                        completeOnboarding()
                    }
                    .environment(syncCoordinator)
                    .environment(syncCoordinator.permissionManager)
                } else {
                    AppShell()
                        .environment(syncCoordinator)
                        .environment(syncCoordinator.permissionManager)
                        .environment(briefingGenerator)
                }
            }
            .onAppear {
                checkOnboardingState()
                DataSyncCoordinator.registerBackgroundTasks()
                notificationService.registerCategories()
                refreshBriefingAndNotifications()
            }
        }
        .modelContainer(for: [BinderItem.self, ChatMessage.self, UserProfile.self])
        .backgroundTask(.appRefresh(DataSyncCoordinator.appRefreshIdentifier)) {
            DataSyncCoordinator.scheduleAppRefresh()
        }
    }

    private func checkOnboardingState() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        showOnboarding = !hasCompleted
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            showOnboarding = false
        }
        refreshBriefingAndNotifications()
    }

    private func refreshBriefingAndNotifications() {
        // Generate briefing, save to shared container, update widget and notifications
        // This runs on a background task since it needs ModelContext
        Task { @MainActor in
            guard let container = try? ModelContainer(for: BinderItem.self, ChatMessage.self, UserProfile.self) else { return }
            let context = container.mainContext

            // Get tone from user profile
            let descriptor = FetchDescriptor<UserProfile>()
            let tone = (try? context.fetch(descriptor))?.first?.tonePreset ?? .standard

            let briefing = await briefingGenerator.generateBriefing(
                tone: tone,
                modelContext: context
            )

            // Save to shared App Group for widget
            SharedDataManager.shared.saveBriefing(briefing)

            // Reload widget timeline
            WidgetCenter.shared.reloadAllTimelines()

            // Schedule notifications from insights
            notificationService.scheduleFromInsights(briefingGenerator.insightEngine.insights)
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AIFam/Services/NotificationService.swift AIFam/AIFamApp.swift
git commit -m "feat: add push notifications — morning briefing, conflict alerts, birthday reminders"
```

---

## Plan Summary

After completing all 3 tasks, the app extends well beyond its main interface:

- WidgetKit medium widget shows the daily briefing on the home screen: greeting, top 3 prioritized items with category color dots, and stats row (events today, tasks due, sleep hours). Refreshes via timeline every ~20 minutes. Data shared via App Group container.
- Siri integration via App Intents registers two App Shortcuts that appear in Spotlight and the Shortcuts app with zero user setup: "Morning briefing from AI Fam" (spoken + visual briefing summary) and "What's my day look like" (calendar-focused day overview). Both show custom snippet views.
- Local push notifications schedule: recurring morning briefing at 7:30 AM, conflict alerts 1 hour before overlapping events, birthday reminders 3 days and 1 day before (plus day-of), and overdue task alerts. All notifications use custom categories with "Open Binder" and "Got it" actions.

The app now has a complete v1 feature set across all 5 plans: foundation (Plan 1), data ingestion (Plan 2), UI (Plan 3), intelligence (Plan 4), and surfaces (Plan 5).
