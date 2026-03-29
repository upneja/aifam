import SwiftUI

struct BinderHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Good morning.")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.primaryText)

                    Text("Your binder is empty. Start chatting to fill it up.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .padding()
            }
            .background(AppColors.background)
        }
    }
}
