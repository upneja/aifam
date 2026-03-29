import Foundation
import SwiftData

@Model
final class BinderItem {
    var id: UUID
    var title: String
    var detail: String
    var categoryRaw: String
    var dueDate: Date?
    var isCompleted: Bool
    var urgencyDays: Int?
    var relatedNotes: [String]
    var source: String
    var sourceID: String?
    var createdAt: Date
    var updatedAt: Date

    var category: BinderCategory {
        get { BinderCategory(rawValue: categoryRaw) ?? .notes }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        title: String,
        detail: String = "",
        category: BinderCategory,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        urgencyDays: Int? = nil,
        relatedNotes: [String] = [],
        source: String = "chat",
        sourceID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.categoryRaw = category.rawValue
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.urgencyDays = urgencyDays
        self.relatedNotes = relatedNotes
        self.source = source
        self.sourceID = sourceID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
