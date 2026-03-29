import SwiftUI

struct ChatView: View {
    @State private var messageText = ""

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    TextField("Talk to your secretary...", text: $messageText)
                        .padding(12)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    Button(action: {}) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
            .navigationTitle("Chat")
        }
    }
}
