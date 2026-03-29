import SwiftUI

enum AppColors {
    // Secretary brand
    static let gold = Color(red: 0.72, green: 0.59, blue: 0.31)         // #b8964e
    static let goldLight = Color(red: 0.98, green: 0.96, blue: 0.93)    // #f9f5ee

    // Category colors
    static let calendar = Color(red: 0.20, green: 0.66, blue: 0.33)     // #34a853
    static let calendarBg = Color(red: 0.91, green: 0.96, blue: 0.95)   // #e8f5f3
    static let tasks = Color(red: 0.79, green: 0.53, blue: 0.04)        // #c9860a
    static let tasksBg = Color(red: 1.00, green: 0.95, blue: 0.89)      // #fef3e2
    static let dates = Color(red: 0.84, green: 0.19, blue: 0.19)        // #d63031
    static let datesBg = Color(red: 0.99, green: 0.91, blue: 0.91)      // #fde8e8
    static let notes = Color(red: 0.49, green: 0.23, blue: 0.93)        // #7c3aed
    static let notesBg = Color(red: 0.93, green: 0.91, blue: 0.96)      // #ede8f5

    // System
    static let background = Color(uiColor: .systemGroupedBackground)     // #f2f2f7
    static let cardBackground = Color(uiColor: .systemBackground)        // #ffffff
    static let primaryText = Color(uiColor: .label)                      // #1c1c1e
    static let secondaryText = Color(uiColor: .secondaryLabel)           // #8e8e93
}
