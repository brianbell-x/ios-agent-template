import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ChatSessionStore {
    var messages: [ChatMessage] = []
    var composerText = ""
    var conversationID: String?
    var activeAgentName = "Assistant"
    var inlineError: String?
    var isStreaming = false
    var persistenceIssue: String?

    private let client: any ChatAPIClient
    private let transcriptStore: TranscriptStore
    private let backendBaseURL: URL
    private let defaultAgentID: String
    private let logger = Logger(subsystem: "com.example.chatagent", category: "ChatSessionStore")
    private var sendTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private var pendingRetryMessage: String?
    private var hasRestoredSnapshot = false
    private var transcriptLimit: Int
    private var persistenceRevision = 0

    init(
        client: any ChatAPIClient,
        transcriptStore: TranscriptStore,
        backendBaseURL: URL,
        defaultAgentID: String,
        localTranscriptLimit: Int
    ) {
        self.client = client
        self.transcriptStore = transcriptStore
        self.backendBaseURL = backendBaseURL
        self.defaultAgentID = defaultAgentID
        self.transcriptLimit = max(1, localTranscriptLimit)
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
            if let snapshotConversationID = snapshot.conversationID {
                let status = try await client.conversationStatus(for: snapshotConversationID)
                transcriptLimit = max(1, status.sessionHistoryLimit)
                guard status.exists else {
                    inlineError = "The previous backend session is no longer available. Starting a new conversation."
                    resetConversationState()
                    schedulePersistence()
                    return
                }
            }

            conversationID = snapshot.conversationID
            activeAgentName = snapshot.activeAgentName
            messages = cappedMessages(snapshot.messages)
        } catch {
            inlineError = "Couldn't verify the previous backend session. Starting a new conversation."
            resetConversationState()
            schedulePersistence()
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
        resetConversationState()
        schedulePersistence()
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
        messages.append(ChatMessage(id: assistantID, role: .assistant, text: "", state: .streaming))
        schedulePersistence()

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
                self.schedulePersistence()
            } catch is CancellationError {
                self.isStreaming = false
                self.schedulePersistence()
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
                self.schedulePersistence()
            }
        }
    }

    private func apply(_ event: ChatStreamEvent, assistantMessageID: UUID) {
        switch event {
        case .conversationStarted(let payload):
            conversationID = payload.conversationID
            transcriptLimit = max(1, payload.sessionHistoryLimit)
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
            transcriptLimit = max(1, payload.sessionHistoryLimit)
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

    private func schedulePersistence() {
        persistenceRevision += 1
        let revision = persistenceRevision
        let snapshotMessages = cappedMessages(messages)
        let snapshot = snapshotMessages.isEmpty
            ? nil
            : ConversationSnapshot(
                conversationID: conversationID,
                activeAgentName: activeAgentName,
                messages: snapshotMessages
            )

        persistenceTask?.cancel()
        persistenceTask = Task { [weak self, transcriptStore, logger] in
            do {
                try await transcriptStore.replace(snapshot: snapshot, revision: revision)
                await MainActor.run {
                    self?.persistenceIssue = nil
                }
            } catch is CancellationError {
                return
            } catch {
                logger.error("Transcript persistence failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self?.persistenceIssue = "Transcript persistence failed."
                }
            }
        }
    }

    private func cappedMessages(_ source: [ChatMessage]) -> [ChatMessage] {
        Array(source.suffix(transcriptLimit))
    }

    private func resetConversationState() {
        conversationID = nil
        activeAgentName = "Assistant"
        messages.removeAll(keepingCapacity: true)
    }
}

private struct PreviewChatAPIClient: ChatAPIClient {
    func conversationStatus(for conversationID: String) async throws -> ConversationStatusPayload {
        ConversationStatusPayload(
            conversationID: conversationID,
            exists: true,
            sessionHistoryLimit: 40
        )
    }

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
            defaultAgentID: "default",
            localTranscriptLimit: 40
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
            defaultAgentID: "default",
            localTranscriptLimit: 40
        )
    }

    static var previewError: ChatSessionStore {
        let store = previewConversation
        store.inlineError = "The backend could not complete the request."
        return store
    }
}
