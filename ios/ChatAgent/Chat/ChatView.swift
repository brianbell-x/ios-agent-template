import Observation
import SwiftUI

struct ChatView: View {
    @Bindable var store: ChatSessionStore

    init(store: ChatSessionStore) {
        self.store = store
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ChatBackground()

                ScrollView {
                    LazyVStack(spacing: 18) {
                        if store.messages.isEmpty {
                            ChatEmptyState(
                                suggestions: [
                                    "Help me plan a launch checklist",
                                    "Summarize a product idea with risks",
                                    "Draft a two-paragraph customer reply",
                                ],
                                onSelectSuggestion: store.useSuggestion
                            )
                            .padding(.top, 24)
                        } else {
                            ForEach(store.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }

                        if let inlineError = store.inlineError {
                            ErrorCard(message: inlineError, retry: store.retryLastMessage)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Assistant")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        Text(store.statusCaption)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: store.startNewConversation) {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(store.isStreaming)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ComposerBar(
                    text: $store.composerText,
                    isSending: store.isStreaming,
                    canSend: store.canSendMessage,
                    send: store.sendCurrentDraft
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.thinMaterial)
            }
            .onChange(of: store.scrollAnchorID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.snappy(duration: 0.28)) {
                    proxy.scrollTo(newValue, anchor: .bottom)
                }
            }
            .onChange(of: store.messages.last?.text) { _, _ in
                guard let anchor = store.scrollAnchorID else { return }
                withAnimation(.snappy(duration: 0.18)) {
                    proxy.scrollTo(anchor, anchor: .bottom)
                }
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 64)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(displayText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                if message.state == .streaming {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: 460, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }

            if message.role == .assistant {
                Spacer(minLength: 64)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var displayText: String {
        if message.text.isEmpty, message.state == .streaming {
            return "Thinking..."
        }
        return message.text
    }

    private var backgroundColor: Color {
        if message.role == .user {
            return Color(red: 0.86, green: 0.93, blue: 0.89)
        }
        return Color.white.opacity(0.82)
    }

    private var borderColor: Color {
        if message.state == .failed {
            return Color.red.opacity(0.3)
        }
        return Color.black.opacity(0.05)
    }
}

private struct ComposerBar: View {
    @Binding var text: String
    let isSending: Bool
    let canSend: Bool
    let send: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                }
                .onSubmit(send)

            Button(action: send) {
                ZStack {
                    Circle()
                        .fill(canSend ? Color(red: 0.17, green: 0.52, blue: 0.37) : Color.gray.opacity(0.25))
                        .frame(width: 44, height: 44)

                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(!canSend)
            .buttonStyle(.plain)
        }
    }
}

private struct ChatEmptyState: View {
    let suggestions: [String]
    let onSelectSuggestion: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start a focused conversation")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("This app keeps the UI focused: one transcript, one composer, and a backend that owns agent behavior.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: { onSelectSuggestion(suggestion) }) {
                        HStack {
                            Text(suggestion)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
        }
    }
}

private struct ErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text("Response interrupted")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(message)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ChatBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.95),
                    Color(red: 0.92, green: 0.95, blue: 0.93),
                    Color(red: 0.96, green: 0.95, blue: 0.92),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.32))
                .frame(width: 260, height: 260)
                .blur(radius: 20)
                .offset(x: -120, y: -240)

            Circle()
                .fill(Color(red: 0.77, green: 0.88, blue: 0.81).opacity(0.32))
                .frame(width: 280, height: 280)
                .blur(radius: 26)
                .offset(x: 160, y: -180)
        }
    }
}

#Preview("Conversation") {
    NavigationStack {
        ChatView(store: .previewConversation)
    }
}

#Preview("Empty") {
    NavigationStack {
        ChatView(store: .previewEmpty)
    }
}

#Preview("Error") {
    NavigationStack {
        ChatView(store: .previewError)
    }
}
