import SwiftUI
import SwiftData

struct BinderHomeView: View {
    @Query(sort: \BinderItem.dueDate) private var allItems: [BinderItem]
    @Environment(DataSyncCoordinator.self) private var syncCoordinator

    private var briefingItems: [BinderItem] {
        let now = Date()
        let calendar = Calendar.current
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now)!

        return allItems
            .filter { item in
                if let dueDate = item.dueDate {
                    return dueDate <= weekFromNow && !item.isCompleted
                }
                return item.urgencyDays != nil && !item.isCompleted
            }
            .sorted { a, b in
                (a.urgencyDays ?? 999) < (b.urgencyDays ?? 999)
            }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        default: return "Good evening."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting)
                            .font(AppTypography.largeTitle)
                            .foregroundStyle(AppColors.primaryText)

                        Text("Here's what needs your attention.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Today's Briefing
                    if !briefingItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Today's Briefing")
                                    .font(AppTypography.title2)
                                    .foregroundStyle(AppColors.primaryText)

                                Spacer()

                                Text("\(briefingItems.count) items")
                                    .font(AppTypography.subheadline)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            .padding(.horizontal)

                            LazyVStack(spacing: 10) {
                                ForEach(briefingItems.prefix(5)) { item in
                                    BriefingCardView(item: item)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        emptyBriefingView
                    }

                    // Category Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Binder")
                            .font(AppTypography.title2)
                            .foregroundStyle(AppColors.primaryText)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(BinderCategory.allCases) { category in
                                NavigationLink(value: category) {
                                    categoryCard(category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(AppColors.background)
            .navigationDestination(for: BinderCategory.self) { category in
                BinderDetailView(category: category)
            }
            .refreshable {
                await syncCoordinator.performDeltaSync()
            }
        }
    }

    private func categoryCard(_ category: BinderCategory) -> some View {
        let count = allItems.filter { $0.category == category && !$0.isCompleted }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(category.color)

                Spacer()

                Text("\(count)")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.primaryText)
            }

            Text(category.displayName)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primaryText)

            Text(categorySubtitle(category, count: count))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(16)
        .background(category.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func categorySubtitle(_ category: BinderCategory, count: Int) -> String {
        switch category {
        case .calendar: count == 1 ? "event this week" : "events this week"
        case .tasks: count == 1 ? "item needs attention" : "items need attention"
        case .dates: count == 1 ? "upcoming date" : "upcoming dates"
        case .notes: count == 1 ? "filed item" : "filed items"
        }
    }

    private var emptyBriefingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.gold)

            Text("You're all caught up.")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primaryText)

            Text("Start chatting to fill your binder, or grant permissions so I can read your data.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
