import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Secretary icon
                ZStack {
                    Circle()
                        .fill(AppColors.goldLight)
                        .frame(width: 120, height: 120)

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.gold)
                }

                VStack(spacing: 12) {
                    Text("Meet your secretary.")
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.primaryText)
                        .multilineTextAlignment(.center)

                    Text("I'll organize your life. But first,\nI need to look through your files.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Let me take a look")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("Everything stays on your device.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.cardBackground)
    }
}
