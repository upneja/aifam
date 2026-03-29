import Foundation
import SwiftData

struct ChatRequestDTO: Encodable {
    let message: String
    let tone: String
    let context: [[String: String]]
}

struct FiledItemDTO: Decodable {
    let title: String
    let detail: String
    let category: String
    let due_date: String?
    let urgency_days: Int?
}

struct ChatResponseDTO: Decodable {
    let reply: String
    let filed_items: [FiledItemDTO]
    let filed_categories: [String]
}

@Observable
@MainActor
final class SecretaryService {
    var isProcessing = false

    func sendMessage(
        _ text: String,
        tone: TonePreset,
        recentMessages: [ChatMessage],
        modelContext: ModelContext
    ) async throws -> ChatMessage {
        isProcessing = true
        defer { isProcessing = false }

        let context = recentMessages.suffix(10).map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
        }

        let request = ChatRequestDTO(
            message: text,
            tone: tone.rawValue,
            context: context
        )

        let response: ChatResponseDTO = try await APIClient.shared.post(
            path: "/chat",
            body: request
        )

        let categories = response.filed_categories.compactMap { BinderCategory(rawValue: $0) }

        for item in response.filed_items {
            guard let category = BinderCategory(rawValue: item.category) else { continue }

            var dueDate: Date?
            if let dateString = item.due_date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                dueDate = formatter.date(from: dateString)
            }

            let binderItem = BinderItem(
                title: item.title,
                detail: item.detail,
                category: category,
                dueDate: dueDate,
                urgencyDays: item.urgency_days,
                source: "chat"
            )
            modelContext.insert(binderItem)
        }

        let assistantMessage = ChatMessage(
            content: response.reply,
            isUser: false,
            filedCategories: categories
        )
        modelContext.insert(assistantMessage)

        try modelContext.save()

        return assistantMessage
    }
}
