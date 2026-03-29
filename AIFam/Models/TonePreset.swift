import Foundation

enum TonePreset: String, Codable, CaseIterable, Identifiable {
    case casual
    case standard
    case professional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: "Casual"
        case .standard: "Default"
        case .professional: "Professional"
        }
    }

    var description: String {
        switch self {
        case .casual: "Your organized roommate who actually has it together"
        case .standard: "Friendly and clear, like a great assistant"
        case .professional: "The executive assistant you wish you could afford"
        }
    }

    var systemPromptFragment: String {
        switch self {
        case .casual:
            "You speak casually like a close friend. Use lowercase, contractions, and informal language. Be direct and a little playful. Example: 'yo heads up — sarah's bday is in 4 days and you haven't planned anything yet.'"
        case .standard:
            "You speak in a friendly, clear tone. Warm but not overly casual. Like a trusted assistant who genuinely cares. Example: 'Sarah's birthday is in 4 days. No plans yet — want me to look into options?'"
        case .professional:
            "You speak formally and efficiently. Precise language, no contractions, structured responses. Like a top-tier executive assistant. Example: 'Reminder: Sarah's birthday dinner is April 12th. Reservations have not been made.'"
        }
    }
}
