import SwiftUI

struct FilingTagView: View {
    let category: BinderCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(category.displayName)
                .font(AppTypography.categoryLabel)
        }
        .foregroundStyle(category.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.backgroundColor)
        .clipShape(Capsule())
    }
}
