import Foundation
import Observation

@MainActor
@Observable
final class ChatSessionStore {
    var messages: [ChatMessage] = []
    var composerText = ""
    var conversationID: String?
    var activeAgentName = "Assistant"
    var inlineError: String?
    var isStreaming = false

    private let client: any ChatAPIClient
    private let transcriptStore: TranscriptStore
    private let backendBaseURL: URL
    private let defaultAgentID: String
    private var sendTask: Task<Void, Never>?
    private var pendingRetryMessage: String?
    private var hasRestoredSnapshot = false

    init(
        client: any ChatAPIClient,
        transcriptStore: TranscriptStore,
        backendBaseURL: URL,
        defaultAgentID: String
    ) {
        self.client = client
        self.transcriptStore = transcriptStore
        self.backendBaseURL = backendBaseURL
        self.defaultAgentID = defaultAgentID
    }

    var canSendMessage: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var scrollAnchorID: UUID? {
        messages.last?.id
    }

    var statusCaption: String {
        if isStreaming {
            return activeAgentName
        }
        if let host = backendBaseURL.host {
            return "Connected to \(host)"
        }
        return backendBaseURL.absoluteString
    }

    func restoreIfNeeded() async {
        guard !hasRestoredSnapshot else { return }
        hasRestoredSnapshot = true

        do {
            guard let snapshot = try await transcriptStore.load() else { return }
            conversationID = snapshot.conversationID
            activeAgentName = snapshot.activeAgentName
            messages = snapshot.messages
        } catch {
            inlineError = "Couldn't restore the previous conversation."
        }
    }

    func sendCurrentDraft() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }
        composerText = ""
        stream(message: trimmed, addUserBubble: true)
    }

    func retryLastMessage() {
        guard let pendingRetryMessage, !isStreaming else { return }
        inlineError = nil
        stream(message: pendingRetryMessage, addUserBubble: false)
    }

    func startNewConversation() {
        sendTask?.cancel()
        sendTask = nil
        isStreaming = false
        pendingRetryMessage = nil
        inlineError = nil
        conversationID = nil
        activeAgentName = "Assistant"
        messages.removeAll(keepingCapacity: true)
        persistSnapshot()
    }

    func useSuggestion(_ prompt: String) {
        composerText = prompt
        sendCurrentDraft()
    }

    private func stream(message: String, addUserBubble: Bool) {
        sendTask?.cancel()
        inlineError = nil
        pendingRetryMessage = message
        isStreaming = true

        if addUserBubble {
            messages.append(ChatMessage(role: .user, text: message))
        }

        let assistantID = UUID()
        messages.append(ChatMessage(role: .assistant, text: "", state: .streaming))
        persistSnapshot()

        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                let request = BackendChatRequest(
                    message: message,
                    conversationID: self.conversationID,
                    agentID: self.defaultAgentID
                )
                for try await event in self.client.streamReply(for: request) {
                    self.apply(event, assistantMessageID: assistantID)
                }
                if let index = self.messages.firstIndex(where: { $0.id == assistantID }) {
                    self.messages[index].state = .complete
                }
                self.pendingRetryMessage = nil
                self.isStreaming = false
                self.persistSnapshot()
            } catch is CancellationError {
                self.isStreaming = false
                self.persistSnapshot()
            } catch {
                self.isStreaming = false
                self.inlineError = error.localizedDescription
                if let index = self.messages.firstIndex(where: { $0.id == assistantID }) {
                    if self.messages[index].text.isEmpty {
                        self.messages.remove(at: index)
                    } else {
                        self.messages[index].state = .failed
                    }
                }
                self.persistSnapshot()
            }
        }
    }

    private func apply(_ event: ChatStreamEvent, assistantMessageID: UUID) {
        switch event {
        case .conversationStarted(let payload):
            conversationID = payload.conversationID
        case .messageDelta(let payload):
            if let index = messages.firstIndex(where: { $0.id == assistantMessageID }) {
                messages[index].text += payload.delta
                messages[index].state = .streaming
            }
        case .agentUpdated(let payload):
            activeAgentName = payload.agentName
        case .runItem(let payload):
            if payload.name == "tool_called" {
                activeAgentName = "Working..."
            }
        case .messageCompleted(let payload):
            conversationID = payload.conversationID
            activeAgentName = payload.finalAgentName
            if let index = messages.firstIndex(where: { $0.id == assistantMessageID }) {
                messages[index].text = payload.content
                messages[index].state = .complete
            }
        case .failure(let payload):
            inlineError = payload.message
        case .done:
            break
        }
    }

    private func persistSnapshot() {
        let snapshot = ConversationSnapshot(
            conversationID: conversationID,
            activeAgentName: activeAgentName,
            messages: messages
        )

        Task {
            do {
                if snapshot.messages.isEmpty {
                    try await transcriptStore.clear()
                } else {
                    try await transcriptStore.save(snapshot)
                }
            } catch {
                // Persistence is best effort for the template.
            }
        }
    }
}

private struct PreviewChatAPIClient: ChatAPIClient {
    func streamReply(for request: BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

extension ChatSessionStore {
    static var previewConversation: ChatSessionStore {
        let store = ChatSessionStore(
            client: PreviewChatAPIClient(),
            transcriptStore: .preview(),
            backendBaseURL: URL(string: "http://127.0.0.1:8000")!,
            defaultAgentID: "default"
        )
        store.messages = [
            ChatMessage(role: .assistant, text: "How can I help today?"),
            ChatMessage(role: .user, text: "Give me a trip plan for two days in Chicago."),
            ChatMessage(
                role: .assistant,
                text: "Day one: architecture river walk, West Loop lunch, museum campus in the afternoon. Day two: Logan Square coffee, neighborhood shopping, then a lakefront sunset.",
                state: .complete
            ),
        ]
        store.activeAgentName = "Planning Specialist"
        store.conversationID = "preview-conversation"
        return store
    }

    static var previewEmpty: ChatSessionStore {
        ChatSessionStore(
            client: PreviewChatAPIClient(),
            transcriptStore: .preview(),
            backendBaseURL: URL(string: "http://127.0.0.1:8000")!,
            defaultAgentID: "default"
        )
    }

    static var previewError: ChatSessionStore {
        let store = previewConversation
        store.inlineError = "The backend could not complete the request."
        return store
    }
}
