import EventKit
import Foundation
import SwiftData

struct CalendarEvent: Sendable {
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let attendeeNames: [String]
    let isAllDay: Bool
    let recurrenceDescription: String?
    let calendarName: String
}

struct CalendarConflict: Sendable {
    let event1Title: String
    let event2Title: String
    let overlapStart: Date
    let overlapEnd: Date
}

@Observable
final class CalendarIngestionService {
    private let eventStore = EKEventStore()

    var lastSyncDate: Date?
    var eventCount: Int = 0

    // MARK: - Fetch Events

    func fetchEvents(months: Int = 1) -> [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()

        guard let startDate = calendar.date(byAdding: .month, value: -1, to: now),
              let endDate = calendar.date(byAdding: .month, value: months, to: now) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let ekEvents = eventStore.events(matching: predicate)
        eventCount = ekEvents.count

        return ekEvents.map { event in
            CalendarEvent(
                eventIdentifier: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                attendeeNames: event.attendees?.compactMap { $0.name } ?? [],
                isAllDay: event.isAllDay,
                recurrenceDescription: event.recurrenceRules?.first.map { describeRecurrence($0) },
                calendarName: event.calendar.title
            )
        }
    }

    // MARK: - Fetch Historical Events (for onboarding)

    func fetchHistoricalEvents(years: Int = 4) -> [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()

        guard let startDate = calendar.date(byAdding: .year, value: -years, to: now),
              let endDate = calendar.date(byAdding: .month, value: 3, to: now) else {
            return []
        }

        // EventKit limits predicate range to 4 years — fetch in 6-month chunks
        var allEvents: [CalendarEvent] = []
        var chunkStart = startDate

        while chunkStart < endDate {
            guard let chunkEnd = calendar.date(byAdding: .month, value: 6, to: chunkStart) else { break }
            let clampedEnd = min(chunkEnd, endDate)

            let predicate = eventStore.predicateForEvents(
                withStart: chunkStart,
                end: clampedEnd,
                calendars: nil
            )

            let ekEvents = eventStore.events(matching: predicate)
            allEvents.append(contentsOf: ekEvents.map { event in
                CalendarEvent(
                    eventIdentifier: event.eventIdentifier,
                    title: event.title ?? "Untitled",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    attendeeNames: event.attendees?.compactMap { $0.name } ?? [],
                    isAllDay: event.isAllDay,
                    recurrenceDescription: event.recurrenceRules?.first.map { describeRecurrence($0) },
                    calendarName: event.calendar.title
                )
            })

            chunkStart = clampedEnd
        }

        eventCount = allEvents.count
        return allEvents
    }

    // MARK: - Detect Conflicts

    func detectConflicts(in events: [CalendarEvent]) -> [CalendarConflict] {
        let nonAllDay = events.filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        var conflicts: [CalendarConflict] = []

        for i in 0..<nonAllDay.count {
            for j in (i + 1)..<nonAllDay.count {
                let a = nonAllDay[i]
                let b = nonAllDay[j]

                // If b starts after a ends, no overlap (sorted, so we can break)
                if b.startDate >= a.endDate { break }

                let overlapStart = max(a.startDate, b.startDate)
                let overlapEnd = min(a.endDate, b.endDate)

                conflicts.append(CalendarConflict(
                    event1Title: a.title,
                    event2Title: b.title,
                    overlapStart: overlapStart,
                    overlapEnd: overlapEnd
                ))
            }
        }

        return conflicts
    }

    // MARK: - Extract Birthdays from Calendar

    func fetchBirthdayEvents() -> [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()

        guard let startDate = calendar.date(byAdding: .month, value: -1, to: now),
              let endDate = calendar.date(byAdding: .year, value: 1, to: now) else {
            return []
        }

        // Find the birthday calendar
        let birthdayCalendars = eventStore.calendars(for: .event).filter {
            $0.type == .birthday
        }

        guard !birthdayCalendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: birthdayCalendars
        )

        return eventStore.events(matching: predicate).map { event in
            CalendarEvent(
                eventIdentifier: event.eventIdentifier,
                title: event.title ?? "Birthday",
                startDate: event.startDate,
                endDate: event.endDate,
                location: nil,
                attendeeNames: [],
                isAllDay: true,
                recurrenceDescription: "yearly",
                calendarName: "Birthdays"
            )
        }
    }

    // MARK: - Extract Attendee Social Graph

    func extractFrequentAttendees(from events: [CalendarEvent], minCount: Int = 3) -> [(name: String, count: Int)] {
        var attendeeCounts: [String: Int] = [:]

        for event in events {
            for name in event.attendeeNames {
                let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else { continue }
                attendeeCounts[normalized, default: 0] += 1
            }
        }

        return attendeeCounts
            .filter { $0.value >= minCount }
            .sorted { $0.value > $1.value }
            .map { (name: $0.key, count: $0.value) }
    }

    // MARK: - Map to BinderItems

    func mapToBinderItems(events: [CalendarEvent], conflicts: [CalendarConflict]) -> [BinderItem] {
        var items: [BinderItem] = []
        let calendar = Calendar.current
        let now = Date()

        // Upcoming events this week -> calendar category
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now)!
        let upcomingEvents = events.filter { $0.startDate >= now && $0.startDate <= weekFromNow && !$0.isAllDay }

        for event in upcomingEvents {
            let daysUntil = calendar.dateComponents([.day], from: now, to: event.startDate).day ?? 0
            let detail = [
                formatEventTime(event.startDate, end: event.endDate),
                event.location,
                event.attendeeNames.isEmpty ? nil : "\(event.attendeeNames.count) attendees"
            ].compactMap { $0 }.joined(separator: " · ")

            let item = BinderItem(
                title: event.title,
                detail: detail,
                category: .calendar,
                dueDate: event.startDate,
                urgencyDays: daysUntil,
                source: "calendar"
            )
            items.append(item)
        }

        // Conflicts -> calendar items with warning
        for conflict in conflicts {
            let item = BinderItem(
                title: "Conflict: \(conflict.event1Title) vs \(conflict.event2Title)",
                detail: "Overlaps \(formatTimeRange(conflict.overlapStart, end: conflict.overlapEnd))",
                category: .calendar,
                dueDate: conflict.overlapStart,
                urgencyDays: 0,
                relatedNotes: ["Schedule conflict detected"],
                source: "calendar"
            )
            items.append(item)
        }

        // Birthday events -> dates category
        let birthdayEvents = fetchBirthdayEvents()
        for birthday in birthdayEvents {
            let daysUntil = calendar.dateComponents([.day], from: now, to: birthday.startDate).day ?? 0
            let item = BinderItem(
                title: birthday.title,
                detail: "From calendar",
                category: .dates,
                dueDate: birthday.startDate,
                urgencyDays: daysUntil,
                relatedNotes: daysUntil <= 7 ? ["Coming up soon"] : [],
                source: "calendar"
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Helpers

    private func describeRecurrence(_ rule: EKRecurrenceRule) -> String {
        switch rule.frequency {
        case .daily: "daily"
        case .weekly: "weekly"
        case .monthly: "monthly"
        case .yearly: "yearly"
        @unknown default: "recurring"
        }
    }

    private func formatEventTime(_ start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) – \(endFormatter.string(from: end))"
    }

    private func formatTimeRange(_ start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
