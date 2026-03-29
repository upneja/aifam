import SwiftUI

enum BinderCategory: String, Codable, CaseIterable, Identifiable {
    case calendar
    case tasks
    case dates
    case notes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calendar: "Calendar"
        case .tasks: "Tasks"
        case .dates: "Dates"
        case .notes: "Notes"
        }
    }

    var color: Color {
        switch self {
        case .calendar: AppColors.calendar
        case .tasks: AppColors.tasks
        case .dates: AppColors.dates
        case .notes: AppColors.notes
        }
    }

    var backgroundColor: Color {
        switch self {
        case .calendar: AppColors.calendarBg
        case .tasks: AppColors.tasksBg
        case .dates: AppColors.datesBg
        case .notes: AppColors.notesBg
        }
    }

    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .tasks: "checklist"
        case .dates: "gift"
        case .notes: "doc.text"
        }
    }
}
