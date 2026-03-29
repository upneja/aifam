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
