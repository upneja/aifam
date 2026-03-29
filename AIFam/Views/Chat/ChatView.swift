import SwiftUI
import SwiftData

struct ChatView: View {
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                emptyStateView
                                    .padding(.top, 60)
                            }

                            ForEach(messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            // Typing indicator
                            if viewModel.isProcessing {
                                typingIndicator
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                inputBar
            }
            .background(AppColors.background)
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !messages.isEmpty {
                        Button("Clear") {
                            viewModel.showClearConfirmation = true
                        }
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
            .alert("Clear Chat?", isPresented: $viewModel.showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearMessages()
                }
            } message: {
                Text("Your binder items will be kept. Only the conversation is cleared.")
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Talk to your secretary...", text: $viewModel.inputText, axis: .vertical)
                .font(AppTypography.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(uiColor: .systemGray4), lineWidth: 0.5)
                )
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }

            if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Mic button
                Button {
                    // Voice input — wired in Plan 5
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(AppColors.gold)
                        .clipShape(Circle())
                }
            } else {
                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(viewModel.isProcessing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.gold.opacity(0.5))

            Text("Talk to your secretary")
                .font(AppTypography.title2)
                .foregroundStyle(AppColors.primaryText)

            Text("Tell me about your life — events, tasks, dates, anything. I'll organize it all into your binder.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Suggestion chips
            VStack(spacing: 8) {
                suggestionChip("sarah's bday is april 12, dinner for 8")
                suggestionChip("lease renewal due end of month")
                suggestionChip("remind me to buy coffee pods")
            }
            .padding(.top, 8)
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            viewModel.inputText = text
            isInputFocused = true
        } label: {
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.gold)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.goldLight)
                .clipShape(Capsule())
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.secondaryText.opacity(0.5))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sendMessage() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        viewModel.inputText = ""
        isInputFocused = false

        // Insert user message
        let userMessage = ChatMessage(content: text, isUser: true)
        modelContext.insert(userMessage)
        try? modelContext.save()

        // Send to secretary
        Task {
            await viewModel.sendMessage(text, messages: messages, modelContext: modelContext)
        }
    }

    private func clearMessages() {
        for message in messages {
            modelContext.delete(message)
        }
        try? modelContext.save()
    }
}
