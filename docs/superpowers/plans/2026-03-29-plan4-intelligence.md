# AI Fam — Plan 4: Intelligence

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add on-device intelligence — entity extraction via Apple Foundation Models, NER via Natural Language framework, a proactive insight engine that generates daily briefings from binder data, and a briefing generator that formats insights per tone preset. After this plan, the app surfaces smart, personalized briefings without any API calls.

**Architecture:** The intelligence layer sits between data ingestion (Plan 2) and UI (Plan 3). `EntityExtractionService` uses iOS 26 Foundation Models with `@Generable` structs to parse chat text into structured entities. `NLEntityExtractor` uses Apple's Natural Language framework for fast NER. `InsightEngine` analyzes all binder data to produce prioritized insights. `BriefingGenerator` formats those insights into the daily briefing per the user's tone preset. All processing is on-device — zero API cost, full privacy.

**Tech Stack:** Swift 6.2, Foundation Models framework (iOS 26), Natural Language framework, SwiftData, iOS 26 SDK

---

## File Structure

### New Files (`AIFam/`)

```
AIFam/
├── Services/
│   ├── EntityExtractionService.swift    # Apple Foundation Models @Generable extraction
│   ├── NLEntityExtractor.swift          # Natural Language NER for people/places/orgs
│   ├── InsightEngine.swift              # Proactive insight generation from binder data
│   └── BriefingGenerator.swift          # Formats insights per tone preset
├── Models/
│   ├── ExtractedEntities.swift          # @Generable structs for entity extraction
│   ├── Insight.swift                    # Insight data model
│   └── Briefing.swift                   # Daily briefing data model
```

---

### Task 1: On-Device Entity Extraction

**Files:**
- Create: `AIFam/Models/ExtractedEntities.swift`
- Create: `AIFam/Services/EntityExtractionService.swift`

- [ ] **Step 1: Write ExtractedEntities.swift**

```swift
import Foundation
import FoundationModels

@Generable
struct ExtractedPerson {
    @Guide(description: "The person's full name")
    var name: String

    @Guide(description: "Relationship to the user, e.g. friend, coworker, mom, partner")
    var relationship: String?

    @Guide(description: "Birthday or relevant date in YYYY-MM-DD format")
    var dateString: String?
}

@Generable
struct ExtractedDate {
    @Guide(description: "Short descriptive title for this date/event")
    var title: String

    @Guide(description: "The date in YYYY-MM-DD format")
    var dateString: String

    @Guide(description: "Number of people involved if mentioned")
    var headcount: Int?

    @Guide(description: "Location or venue if mentioned")
    var location: String?

    @Guide(description: "Additional context or notes")
    var notes: String?
}

@Generable
struct ExtractedTask {
    @Guide(description: "What needs to be done")
    var title: String

    @Guide(description: "Due date in YYYY-MM-DD format, if mentioned")
    var dueDateString: String?

    @Guide(description: "Priority: high, medium, or low")
    var priority: String?

    @Guide(description: "Additional details or context")
    var details: String?
}

@Generable
struct ExtractedNote {
    @Guide(description: "Topic or subject of the note")
    var topic: String

    @Guide(description: "The content to remember")
    var content: String

    @Guide(description: "Related person if any")
    var relatedPerson: String?
}

@Generable
struct ExtractionResult {
    @Guide(description: "People mentioned in the text")
    var people: [ExtractedPerson]

    @Guide(description: "Dates, events, birthdays, or deadlines mentioned")
    var dates: [ExtractedDate]

    @Guide(description: "Tasks, to-dos, or action items mentioned")
    var tasks: [ExtractedTask]

    @Guide(description: "General notes or facts to remember")
    var notes: [ExtractedNote]
}
```

- [ ] **Step 2: Write EntityExtractionService.swift**

```swift
import Foundation
import FoundationModels
import SwiftData

@Observable
final class EntityExtractionService {
    var isProcessing = false
    var lastExtractionDate: Date?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Extract Entities from Text

    func extractEntities(from text: String) async throws -> ExtractionResult {
        isProcessing = true
        defer { isProcessing = false }

        guard LanguageModelSession.isAvailable else {
            // Fallback: return empty result if Foundation Models unavailable
            return ExtractionResult(people: [], dates: [], tasks: [], notes: [])
        }

        let session = LanguageModelSession()

        let prompt = """
        Extract all structured information from this text. \
        Find any people, dates/events/birthdays, tasks/to-dos, and general notes. \
        If a date is relative (e.g., "next Tuesday", "end of month"), convert it to YYYY-MM-DD \
        based on today being \(todayString()). \
        Only extract what is explicitly stated or strongly implied.

        Text: "\(text)"
        """

        let result = try await session.respond(to: prompt, generating: ExtractionResult.self)

        lastExtractionDate = Date()
        return result
    }

    // MARK: - Map Extraction to BinderItems

    func mapToBinderItems(_ result: ExtractionResult) -> [BinderItem] {
        var items: [BinderItem] = []
        let now = Date()
        let calendar = Calendar.current

        // People with dates → Dates category
        for person in result.people {
            if let dateStr = person.dateString, let date = dateFormatter.date(from: dateStr) {
                let daysUntil = calendar.dateComponents([.day], from: now, to: date).day ?? 0
                let relationship = person.relationship ?? "person"

                items.append(BinderItem(
                    title: "\(person.name)'s Birthday",
                    detail: "\(formatDisplayDate(date)) · \(relationship)",
                    category: .dates,
                    dueDate: date,
                    urgencyDays: daysUntil,
                    relatedNotes: [],
                    source: "chat"
                ))
            }
        }

        // Dates → Dates or Calendar category
        for extractedDate in result.dates {
            guard let date = dateFormatter.date(from: extractedDate.dateString) else { continue }
            let daysUntil = calendar.dateComponents([.day], from: now, to: date).day ?? 0

            var detailParts: [String] = [formatDisplayDate(date)]
            if let location = extractedDate.location { detailParts.append(location) }
            if let headcount = extractedDate.headcount { detailParts.append("\(headcount) people") }

            let relatedNotes = extractedDate.notes.map { [$0] } ?? []

            items.append(BinderItem(
                title: extractedDate.title,
                detail: detailParts.joined(separator: " · "),
                category: .dates,
                dueDate: date,
                urgencyDays: daysUntil,
                relatedNotes: relatedNotes,
                source: "chat"
            ))
        }

        // Tasks → Tasks category
        for task in result.tasks {
            var dueDate: Date?
            var daysUntil: Int?

            if let dateStr = task.dueDateString, let date = dateFormatter.date(from: dateStr) {
                dueDate = date
                daysUntil = calendar.dateComponents([.day], from: now, to: date).day
            }

            let detail = task.details ?? ""

            items.append(BinderItem(
                title: task.title,
                detail: detail,
                category: .tasks,
                dueDate: dueDate,
                urgencyDays: daysUntil,
                source: "chat"
            ))
        }

        // Notes → Notes category
        for note in result.notes {
            var relatedNotes: [String] = []
            if let person = note.relatedPerson {
                relatedNotes.append("Related: \(person)")
            }

            items.append(BinderItem(
                title: note.topic,
                detail: note.content,
                category: .notes,
                relatedNotes: relatedNotes,
                source: "chat"
            ))
        }

        return items
    }

    // MARK: - Helpers

    private func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    private func formatDisplayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED. Note: Foundation Models framework is only available on physical devices with Apple Silicon. Simulator builds will compile but the `isAvailable` check will return false.

- [ ] **Step 4: Commit**

```bash
git add AIFam/Models/ExtractedEntities.swift AIFam/Services/EntityExtractionService.swift
git commit -m "feat: add on-device entity extraction via Apple Foundation Models @Generable"
```

---

### Task 2: Natural Language Framework Integration

**Files:**
- Create: `AIFam/Services/NLEntityExtractor.swift`

- [ ] **Step 1: Write NLEntityExtractor.swift**

```swift
import NaturalLanguage
import Foundation

struct NLEntity: Sendable {
    let text: String
    let type: NLEntityType
    let range: Range<String.Index>
}

enum NLEntityType: String, Sendable {
    case person
    case place
    case organization
    case date
    case unknown
}

final class NLEntityExtractor: Sendable {

    // MARK: - Named Entity Recognition

    func extractEntities(from text: String) -> [NLEntity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        var entities: [NLEntity] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, tokenRange in
            guard let tag else { return true }

            let entityType: NLEntityType
            switch tag {
            case .personalName:
                entityType = .person
            case .placeName:
                entityType = .place
            case .organizationName:
                entityType = .organization
            default:
                return true
            }

            let entity = NLEntity(
                text: String(text[tokenRange]),
                type: entityType,
                range: tokenRange
            )
            entities.append(entity)

            return true
        }

        return entities
    }

    // MARK: - Person Name Extraction (focused)

    func extractPersonNames(from text: String) -> [String] {
        extractEntities(from: text)
            .filter { $0.type == .person }
            .map { $0.text }
    }

    // MARK: - Place Extraction (focused)

    func extractPlaces(from text: String) -> [String] {
        extractEntities(from: text)
            .filter { $0.type == .place }
            .map { $0.text }
    }

    // MARK: - Organization Extraction (focused)

    func extractOrganizations(from text: String) -> [String] {
        extractEntities(from: text)
            .filter { $0.type == .organization }
            .map { $0.text }
    }

    // MARK: - Sentiment Analysis

    func analyzeSentiment(of text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0
    }

    // MARK: - Language Detection

    func detectLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    // MARK: - Tokenization (for preprocessing)

    func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            tokens.append(String(text[tokenRange]))
            return true
        }

        return tokens
    }

    // MARK: - Cross-reference with Contacts

    func matchEntitiesToContacts(
        entities: [NLEntity],
        contactNames: [String]
    ) -> [(entity: NLEntity, matchedContact: String)] {
        var matches: [(entity: NLEntity, matchedContact: String)] = []

        for entity in entities where entity.type == .person {
            let entityName = entity.text.lowercased()

            // Exact match
            if let match = contactNames.first(where: { $0.lowercased() == entityName }) {
                matches.append((entity: entity, matchedContact: match))
                continue
            }

            // Partial match (first name)
            if let match = contactNames.first(where: {
                $0.lowercased().hasPrefix(entityName) ||
                $0.lowercased().components(separatedBy: " ").first == entityName
            }) {
                matches.append((entity: entity, matchedContact: match))
            }
        }

        return matches
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AIFam/Services/NLEntityExtractor.swift
git commit -m "feat: add Natural Language NER — people, places, orgs, sentiment analysis"
```

---

### Task 3: Proactive Insight Engine

**Files:**
- Create: `AIFam/Models/Insight.swift`
- Create: `AIFam/Services/InsightEngine.swift`

- [ ] **Step 1: Write Insight.swift**

```swift
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
```

- [ ] **Step 2: Write InsightEngine.swift**

```swift
import Foundation
import SwiftData

@Observable
final class InsightEngine {
    var insights: [Insight] = []
    var lastGeneratedAt: Date?

    private let healthService: HealthIngestionService

    init(healthService: HealthIngestionService = HealthIngestionService()) {
        self.healthService = healthService
    }

    // MARK: - Generate All Insights

    @MainActor
    func generateInsights(modelContext: ModelContext) async {
        var newInsights: [Insight] = []

        let allItems = fetchAllItems(modelContext: modelContext)

        newInsights.append(contentsOf: detectCalendarConflicts(items: allItems))
        newInsights.append(contentsOf: detectUpcomingBirthdays(items: allItems))
        newInsights.append(contentsOf: detectOverdueTasks(items: allItems))
        newInsights.append(contentsOf: detectUpcomingDeadlines(items: allItems))
        newInsights.append(contentsOf: detectBusyDays(items: allItems))
        newInsights.append(contentsOf: detectNoPlanWarnings(items: allItems))
        newInsights.append(contentsOf: await detectSleepQuality())

        // Sort by priority (critical first), then by creation date
        insights = newInsights.sorted { a, b in
            if a.priority != b.priority { return a.priority < b.priority }
            return a.createdAt < b.createdAt
        }

        lastGeneratedAt = Date()
    }

    // MARK: - Fetch Items

    private func fetchAllItems(modelContext: ModelContext) -> [BinderItem] {
        let descriptor = FetchDescriptor<BinderItem>(
            predicate: #Predicate<BinderItem> { !$0.isCompleted }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Calendar Conflicts

    private func detectCalendarConflicts(items: [BinderItem]) -> [Insight] {
        let calendarItems = items.filter { $0.category == .calendar }

        return calendarItems
            .filter { $0.title.hasPrefix("Conflict:") }
            .map { item in
                Insight(
                    type: .calendarConflict,
                    priority: .critical,
                    title: item.title,
                    detail: item.detail,
                    category: .calendar,
                    relatedItemTitle: item.title,
                    actionSuggestion: "Reschedule one of these events"
                )
            }
    }

    // MARK: - Upcoming Birthdays

    private func detectUpcomingBirthdays(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        return items
            .filter { $0.category == .dates && $0.title.lowercased().contains("birthday") }
            .compactMap { item -> Insight? in
                guard let dueDate = item.dueDate else { return nil }
                let daysUntil = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 999
                guard daysUntil >= 0 && daysUntil <= 14 else { return nil }

                let priority: InsightPriority
                if daysUntil <= 1 { priority = .critical }
                else if daysUntil <= 3 { priority = .high }
                else if daysUntil <= 7 { priority = .medium }
                else { priority = .low }

                let hasPlans = !item.relatedNotes.isEmpty &&
                    !item.relatedNotes.contains("No gift or plan yet")

                let action = hasPlans ? nil : "No plans yet — want me to help?"

                return Insight(
                    type: .upcomingBirthday,
                    priority: priority,
                    title: item.title,
                    detail: daysUntil == 0 ? "Today!" : daysUntil == 1 ? "Tomorrow" : "In \(daysUntil) days",
                    category: .dates,
                    relatedItemTitle: item.title,
                    actionSuggestion: action
                )
            }
    }

    // MARK: - Overdue Tasks

    private func detectOverdueTasks(items: [BinderItem]) -> [Insight] {
        let now = Date()

        return items
            .filter { $0.category == .tasks }
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                return dueDate < now
            }
            .map { item in
                let calendar = Calendar.current
                let daysOverdue = calendar.dateComponents([.day], from: item.dueDate!, to: now).day ?? 0

                return Insight(
                    type: .overdueTask,
                    priority: .critical,
                    title: "Overdue: \(item.title)",
                    detail: daysOverdue == 1 ? "1 day overdue" : "\(daysOverdue) days overdue",
                    category: .tasks,
                    relatedItemTitle: item.title,
                    actionSuggestion: "Complete or reschedule this task"
                )
            }
    }

    // MARK: - Upcoming Deadlines

    private func detectUpcomingDeadlines(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        return items
            .filter { $0.category == .tasks && $0.dueDate != nil }
            .compactMap { item -> Insight? in
                let daysUntil = calendar.dateComponents([.day], from: now, to: item.dueDate!).day ?? 999
                guard daysUntil >= 0 && daysUntil <= 3 else { return nil }

                return Insight(
                    type: .upcomingDeadline,
                    priority: daysUntil == 0 ? .critical : .high,
                    title: item.title,
                    detail: daysUntil == 0 ? "Due today" : "Due in \(daysUntil) day\(daysUntil == 1 ? "" : "s")",
                    category: .tasks,
                    relatedItemTitle: item.title,
                    actionSuggestion: nil
                )
            }
    }

    // MARK: - Busy Day Detection

    private func detectBusyDays(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        // Group today's calendar items
        let todayItems = items.filter { item in
            guard item.category == .calendar, let dueDate = item.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: now)
        }

        guard todayItems.count >= 4 else { return [] }

        return [Insight(
            type: .busyDay,
            priority: .medium,
            title: "Busy day ahead",
            detail: "\(todayItems.count) events scheduled today",
            category: .calendar,
            actionSuggestion: nil
        )]
    }

    // MARK: - No Plan Warnings

    private func detectNoPlanWarnings(items: [BinderItem]) -> [Insight] {
        let calendar = Calendar.current
        let now = Date()

        return items
            .filter { $0.category == .dates }
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                let daysUntil = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 999
                return daysUntil >= 0 && daysUntil <= 7
            }
            .filter { $0.relatedNotes.contains("No gift or plan yet") }
            .map { item in
                Insight(
                    type: .noPlansWarning,
                    priority: .high,
                    title: "No plans for \(item.title)",
                    detail: "Coming up soon with nothing arranged",
                    category: .dates,
                    relatedItemTitle: item.title,
                    actionSuggestion: "Want me to help plan something?"
                )
            }
    }

    // MARK: - Sleep Quality

    private func detectSleepQuality() async -> [Insight] {
        guard let sleep = await healthService.fetchLastNightSleep() else { return [] }

        let hours = Int(sleep.totalMinutes) / 60
        let mins = Int(sleep.totalMinutes) % 60

        let priority: InsightPriority
        let suggestion: String?

        switch sleep.quality {
        case .good:
            priority = .low
            suggestion = nil
        case .fair:
            priority = .medium
            suggestion = "Consider an earlier bedtime tonight"
        case .poor:
            priority = .high
            suggestion = "You might want to take it easy today"
        }

        return [Insight(
            type: .sleepQuality,
            priority: priority,
            title: "Last night: \(hours)h \(mins)m — \(sleep.quality.displayName)",
            detail: sleepBreakdown(sleep),
            category: .notes,
            actionSuggestion: suggestion
        )]
    }

    private func sleepBreakdown(_ sleep: SleepSummary) -> String {
        var parts: [String] = []
        if sleep.deepMinutes > 0 {
            parts.append("\(Int(sleep.deepMinutes))m deep")
        }
        if sleep.remMinutes > 0 {
            parts.append("\(Int(sleep.remMinutes))m REM")
        }
        if sleep.awakeMinutes > 0 {
            parts.append("\(Int(sleep.awakeMinutes))m awake")
        }
        return parts.isEmpty ? "No stage data" : parts.joined(separator: " · ")
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AIFam/Models/Insight.swift AIFam/Services/InsightEngine.swift
git commit -m "feat: add proactive insight engine — conflicts, birthdays, overdue, sleep quality"
```

---

### Task 4: Briefing Generator

**Files:**
- Create: `AIFam/Models/Briefing.swift`
- Create: `AIFam/Services/BriefingGenerator.swift`

- [ ] **Step 1: Write Briefing.swift**

```swift
import Foundation

struct Briefing: Sendable {
    let greeting: String
    let summary: String
    let items: [BriefingItem]
    let stats: BriefingStats
    let generatedAt: Date
}

struct BriefingItem: Identifiable, Sendable {
    let id: UUID
    let text: String
    let category: BinderCategory
    let priority: InsightPriority
    let actionSuggestion: String?

    init(
        text: String,
        category: BinderCategory,
        priority: InsightPriority,
        actionSuggestion: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.category = category
        self.priority = priority
        self.actionSuggestion = actionSuggestion
    }
}

struct BriefingStats: Sendable {
    let eventsToday: Int
    let tasksDue: Int
    let upcomingDates: Int
    let sleepHours: Double?
    let stepsToday: Int?
}
```

- [ ] **Step 2: Write BriefingGenerator.swift**

```swift
import Foundation
import SwiftData

@Observable
final class BriefingGenerator {
    var currentBriefing: Briefing?
    var isGenerating = false

    private let insightEngine: InsightEngine

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
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AIFam/Models/Briefing.swift AIFam/Services/BriefingGenerator.swift
git commit -m "feat: add briefing generator — tone-aware formatting, stats, daily briefing content"
```

---

## Plan Summary

After completing all 4 tasks, the intelligence layer is operational:

- Entity extraction uses iOS 26 Foundation Models framework with `@Generable` structs to parse natural language into structured people, dates, tasks, and notes — all on-device with zero API cost
- NL entity extraction uses Apple's Natural Language framework for fast NER (people, places, organizations), sentiment analysis, and contact cross-referencing
- Proactive insight engine analyzes all binder data to detect: calendar conflicts, upcoming birthdays (with "no plans" warnings), overdue tasks, approaching deadlines, busy days, and sleep quality issues — prioritized as critical/high/medium/low
- Briefing generator formats all insights per the user's tone preset (casual/standard/professional) with distinct voice for each, computes daily stats (events today, tasks due, upcoming dates, sleep hours), and produces the "Today's Briefing" content

Plan 5 builds on this: surfaces push briefings and insights to WidgetKit, Siri via App Intents, and local push notifications.
