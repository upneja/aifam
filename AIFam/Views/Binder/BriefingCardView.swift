import SwiftUI

struct BriefingCardView: View {
    let item: BinderItem

    var body: some View {
        HStack(spacing: 14) {
            // Category color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(item.category.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.primaryText)

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                if !item.relatedNotes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.relatedNotes, id: \.self) { note in
                            Text(note)
                                .font(AppTypography.caption)
                                .foregroundStyle(item.category.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(item.category.backgroundColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            // Urgency badge
            if let days = item.urgencyDays {
                urgencyBadge(days: days)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    @ViewBuilder
    private func urgencyBadge(days: Int) -> some View {
        let (text, color) = urgencyDisplay(days: days)
        Text(text)
            .font(AppTypography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }

    private func urgencyDisplay(days: Int) -> (String, Color) {
        if days < 0 {
            return ("Overdue", AppColors.dates)
        } else if days == 0 {
            return ("Today", AppColors.dates)
        } else if days <= 3 {
            return ("\(days)d", AppColors.dates)
        } else if days <= 7 {
            return ("\(days)d", AppColors.tasks)
        } else {
            return ("\(days)d", AppColors.secondaryText)
        }
    }
}
