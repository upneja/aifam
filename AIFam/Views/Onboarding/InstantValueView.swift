import SwiftUI
import SwiftData

struct InstantValueView: View {
    let ingestedCount: Int
    let onComplete: () -> Void

    @Query(sort: \BinderItem.dueDate) private var items: [BinderItem]
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(DataSyncCoordinator.self) private var syncCoordinator

    private var topInsights: [BinderItem] {
        Array(items.filter { !$0.isCompleted }.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.gold)

                    Text("Your file is ready.")
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.primaryText)

                    Text("Here's what I found.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .padding(.top, 32)

                // Top insights
                if !topInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Needs Attention")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.primaryText)
                            .padding(.horizontal)

                        ForEach(topInsights) { item in
                            BriefingCardView(item: item)
                                .padding(.horizontal)
                        }
                    }
                }

                // Stats grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Life at a Glance")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.primaryText)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        statCard(
                            value: "\(syncCoordinator.calendarService.eventCount)",
                            label: "Events scanned",
                            icon: "calendar",
                            color: AppColors.calendar
                        )
                        statCard(
                            value: "\(syncCoordinator.contactsService.contactCount)",
                            label: "People mapped",
                            icon: "person.2.fill",
                            color: AppColors.gold
                        )
                        statCard(
                            value: "\(syncCoordinator.remindersService.overdueCount)",
                            label: "Overdue tasks",
                            icon: "exclamationmark.circle",
                            color: AppColors.dates
                        )
                        statCard(
                            value: "\(permissionManager.grantedCount)",
                            label: "Sources active",
                            icon: "antenna.radiowaves.left.and.right",
                            color: AppColors.notes
                        )
                    }
                    .padding(.horizontal)
                }

                // CTA
                Button(action: onComplete) {
                    Text("Open Your Binder")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.cardBackground)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.primaryText)

            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
