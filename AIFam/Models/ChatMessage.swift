import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isUser: Bool
    var filedCategoriesRaw: [String]
    var createdAt: Date

    var filedCategories: [BinderCategory] {
        get { filedCategoriesRaw.compactMap { BinderCategory(rawValue: $0) } }
        set { filedCategoriesRaw = newValue.map { $0.rawValue } }
    }

    init(content: String, isUser: Bool, filedCategories: [BinderCategory] = []) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.filedCategoriesRaw = filedCategories.map { $0.rawValue }
        self.createdAt = Date()
    }
}
