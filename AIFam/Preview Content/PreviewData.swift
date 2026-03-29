import Foundation

enum PreviewData {
    nonisolated(unsafe) static let binderItems: [BinderItem] = [
        BinderItem(
            title: "Sarah's Birthday Dinner",
            detail: "April 12 · Downtown · 8 people",
            category: .dates,
            dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
            urgencyDays: 4,
            relatedNotes: ["3 restaurant options saved"],
            source: "chat"
        ),
        BinderItem(
            title: "Lease Renewal Due",
            detail: "April 30 · Reminder set for April 25",
            category: .tasks,
            dueDate: Calendar.current.date(byAdding: .day, value: 22, to: Date()),
            urgencyDays: 22,
            source: "chat"
        ),
        BinderItem(
            title: "Mom's Birthday",
            detail: "April 16 · From contacts",
            category: .dates,
            dueDate: Calendar.current.date(byAdding: .day, value: 8, to: Date()),
            urgencyDays: 8,
            relatedNotes: ["No gift or plan yet"],
            source: "contacts"
        ),
        BinderItem(
            title: "Team Standup",
            detail: "Daily at 2:30 PM · Conflicts with dentist",
            category: .calendar,
            source: "calendar"
        ),
        BinderItem(
            title: "Coffee pods running low",
            detail: "Last ordered 3 weeks ago",
            category: .tasks,
            source: "chat"
        ),
    ]

    nonisolated(unsafe) static let chatMessages: [ChatMessage] = [
        ChatMessage(
            content: "hey sarah's bday is april 12 and we're doing dinner downtown for like 8 people. also lease renewal is end of month",
            isUser: true
        ),
        ChatMessage(
            content: "Filed both. Sarah's dinner is in Dates — want me to find restaurant options? Lease renewal is in Tasks with a reminder set for the 25th.",
            isUser: false,
            filedCategories: [.dates, .tasks]
        ),
        ChatMessage(content: "ya find some good spots", isUser: true),
        ChatMessage(
            content: "On it. I'll put options in Notes under \"Sarah's Birthday.\"",
            isUser: false,
            filedCategories: [.notes]
        ),
    ]
}
