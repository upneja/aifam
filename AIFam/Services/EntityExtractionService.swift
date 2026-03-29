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

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            // Fallback: return empty result if Foundation Models unavailable
            // TODO: Add NLEntityExtractor-based fallback when Foundation Models not available
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

        let response = try await session.respond(to: prompt, generating: ExtractionResult.self)

        lastExtractionDate = Date()
        return response.content
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

            let relatedNotes: [String] = if let notes = extractedDate.notes { [notes] } else { [] }

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
