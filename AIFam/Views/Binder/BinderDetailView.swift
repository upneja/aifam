import SwiftUI
import SwiftData

struct BinderDetailView: View {
    let category: BinderCategory

    @Query private var allItems: [BinderItem]
    @State private var showCompleted = false

    private var filteredItems: [BinderItem] {
        allItems
            .filter { $0.category == category }
            .filter { showCompleted || !$0.isCompleted }
            .sorted { a, b in
                // Overdue first, then by urgency, then by date
                if let aUrgency = a.urgencyDays, let bUrgency = b.urgencyDays {
                    if aUrgency < 0 && bUrgency >= 0 { return true }
                    if bUrgency < 0 && aUrgency >= 0 { return false }
                    return aUrgency < bUrgency
                }
                if a.urgencyDays != nil { return true }
                if b.urgencyDays != nil { return false }
                return a.createdAt > b.createdAt
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredItems) { item in
                        detailRow(item)
                    }
                }
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle(category.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show Completed", isOn: $showCompleted)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(category.color)
                }
            }
        }
    }

    private func detailRow(_ item: BinderItem) -> some View {
        HStack(spacing: 14) {
            // Completion toggle for tasks
            if category == .tasks {
                Button {
                    withAnimation(.snappy) {
                        item.isCompleted.toggle()
                        item.updatedAt = Date()
                    }
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(item.isCompleted ? AppColors.calendar : AppColors.secondaryText)
                }
            }

            // Category accent dot
            if category != .tasks {
                Circle()
                    .fill(category.color)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.primaryText)
                    .strikethrough(item.isCompleted, color: AppColors.secondaryText)

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                // Cross-references
                if !item.relatedNotes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.secondaryText)

                        ForEach(item.relatedNotes, id: \.self) { note in
                            Text(note)
                                .font(AppTypography.caption)
                                .foregroundStyle(category.color)
                        }
                    }
                }

                // Source tag
                HStack(spacing: 4) {
                    Image(systemName: sourceIcon(item.source))
                        .font(.system(size: 9))
                    Text("from \(item.source)")
                        .font(AppTypography.footnote)
                }
                .foregroundStyle(AppColors.secondaryText.opacity(0.7))
            }

            Spacer()

            // Countdown badge
            if let days = item.urgencyDays, !item.isCompleted {
                countdownBadge(days: days)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    @ViewBuilder
    private func countdownBadge(days: Int) -> some View {
        let (text, bgColor, textColor) = countdownStyle(days: days)

        VStack(spacing: 2) {
            Text(text)
                .font(AppTypography.caption)
                .fontWeight(.bold)
            if days >= 0 {
                Text(days == 1 ? "day" : "days")
                    .font(.system(size: 9))
            }
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func countdownStyle(days: Int) -> (String, Color, Color) {
        if days < 0 {
            return ("Overdue", AppColors.dates.opacity(0.15), AppColors.dates)
        } else if days == 0 {
            return ("Today", AppColors.dates.opacity(0.15), AppColors.dates)
        } else if days <= 3 {
            return ("\(days)", AppColors.dates.opacity(0.15), AppColors.dates)
        } else if days <= 7 {
            return ("\(days)", AppColors.tasks.opacity(0.15), AppColors.tasks)
        } else {
            return ("\(days)", AppColors.secondaryText.opacity(0.1), AppColors.secondaryText)
        }
    }

    private func sourceIcon(_ source: String) -> String {
        switch source {
        case "calendar": "calendar"
        case "contacts": "person.2"
        case "reminders": "checklist"
        case "health": "heart"
        case "chat": "bubble.left"
        default: "doc"
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 44))
                .foregroundStyle(category.color.opacity(0.4))

            Text("No \(category.displayName.lowercased()) yet")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primaryText)

            Text("Items will appear here as I find them in your data or you tell me about them in chat.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}
