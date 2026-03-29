import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(AppTypography.body)
                    .foregroundStyle(message.isUser ? .white : AppColors.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(ChatBubbleShape(isUser: message.isUser))

                // Filing tags (assistant messages only)
                if !message.isUser && !message.filedCategories.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.filedCategories, id: \.rawValue) { category in
                            FilingTagView(category: category)
                        }
                    }
                }

                // Timestamp
                Text(formatTimestamp(message.createdAt))
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.secondaryText.opacity(0.6))
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: Color {
        message.isUser ? Color.blue : Color(uiColor: .systemGray5)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if isUser {
            // User bubble: rounded with tail on bottom-right
            path.addRoundedRect(
                in: CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Small tail
            path.move(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - 12))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.maxX - 2, y: rect.maxY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - tailSize - 4, y: rect.maxY),
                control: CGPoint(x: rect.maxX - tailSize, y: rect.maxY)
            )
        } else {
            // Assistant bubble: rounded with tail on bottom-left
            path.addRoundedRect(
                in: CGRect(x: tailSize, y: rect.minY, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Small tail
            path.move(to: CGPoint(x: tailSize, y: rect.maxY - 12))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.maxY),
                control: CGPoint(x: 2, y: rect.maxY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: tailSize + 4, y: rect.maxY),
                control: CGPoint(x: tailSize, y: rect.maxY)
            )
        }

        return path
    }
}
