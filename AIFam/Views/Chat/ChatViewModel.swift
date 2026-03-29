import Foundation
import SwiftData

@Observable
@MainActor
final class ChatViewModel {
    var inputText = ""
    var isProcessing = false
    var showClearConfirmation = false
    var error: String?

    private let secretaryService = SecretaryService()

    func sendMessage(
        _ text: String,
        messages: [ChatMessage],
        modelContext: ModelContext
    ) async {
        guard !isProcessing else { return }

        isProcessing = true
        error = nil

        do {
            // Fetch user profile for tone preference
            let descriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(descriptor)
            let tone = profiles.first?.tonePreset ?? .standard

            _ = try await secretaryService.sendMessage(
                text,
                tone: tone,
                recentMessages: messages,
                modelContext: modelContext
            )
        } catch {
            // Create error message from the secretary
            let errorMessage = ChatMessage(
                content: "Sorry, I couldn't process that right now. Try again in a moment.",
                isUser: false
            )
            modelContext.insert(errorMessage)
            try? modelContext.save()

            self.error = error.localizedDescription
        }

        isProcessing = false
    }
}
