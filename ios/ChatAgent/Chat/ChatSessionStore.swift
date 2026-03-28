import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ChatScreenModel {
    enum RestoreIssue: Equatable {
        case missingRemoteConversation
        case unverifiedConversation

        var inlineErrorCopy: String? {
            switch self {
            case .missingRemoteConversation:
                return "The previous backend session is no longer available. Starting a new conversation."
            case .unverifiedConversation:
                return nil
            }
        }

        var statusCaptionOverride: String? {
            switch self {
            case .missingRemoteConversation:
                return nil
            case .unverifiedConversation:
                return "Session unverified"
            }
        }
    }

    enum SendFailure: Equatable {
        case backend(code: String, message: String)
        case transport(message: String)

        var inlineErrorCopy: String {
            switch self {
            case .backend(_, let message), .transport(let message):
                return message
            }
        }

        var logKind: String {
            switch self {
            case .backend:
                return "backend"
            case .transport:
                return "transport"
            }
        }
    }

    var messages: [ChatMessage] = []
    var composerText = ""
    var isStreaming = false
    var persistenceIssue: String?
    var connectionStatusCaption: String
    var activeAgentName = "Assistant"
    var restoreIssue: RestoreIssue?
    var sendFailure: SendFailure?

    @ObservationIgnored private var sendCurrentDraftAction: () -> Void = {}
    @ObservationIgnored private var retryLastMessageAction: () -> Void = {}
    @ObservationIgnored private var startNewConversationAction: () -> Void = {}
    @ObservationIgnored private var useSuggestionAction: (String) -> Void = { _ in }

    init(connectionStatusCaption: String) {
        self.connectionStatusCaption = connectionStatusCaption
    }

    var canSendMessage: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var inlineError: String? {
        sendFailure?.inlineErrorCopy ?? restoreIssue?.inlineErrorCopy
    }

    var statusCaption: String {
        if isStreaming {
            return activeAgentName
        }
        if let statusCaptionOverride = restoreIssue?.statusCaptionOverride {
            return statusCaptionOverride
        }
        return connectionStatusCaption
    }

    var scrollAnchorID: UUID? {
        messages.last?.id
    }

    func bindActions(
        sendCurrentDraft: @escaping () -> Void,
        retryLastMessage: @escaping () -> Void,
        startNewConversation: @escaping () -> Void,
        useSuggestion: @escaping (String) -> Void
    ) {
        sendCurrentDraftAction = sendCurrentDraft
        retryLastMessageAction = retryLastMessage
        startNewConversationAction = startNewConversation
        useSuggestionAction = useSuggestion
    }

    func sendCurrentDraft() {
        sendCurrentDraftAction()
    }

    func retryLastMessage() {
        retryLastMessageAction()
    }

    func startNewConversation() {
        startNewConversationAction()
    }

    func useSuggestion(_ prompt: String) {
        useSuggestionAction(prompt)
    }
}

@MainActor
final class ChatSessionStore {
    let screen: ChatScreenModel

    private let coordinator: ChatSessionCoordinator

    init(
        client: any ChatAPIClient,
        transcriptStore: TranscriptStore,
        backendBaseURL: URL,
        agentOverrideID: String? = nil,
        localTranscriptLimit: Int
    ) {
        let screen = ChatScreenModel(
            connectionStatusCaption: ChatSessionCoordinator.defaultStatusCaption(for: backendBaseURL)
        )
        self.screen = screen
        self.coordinator = ChatSessionCoordinator(
            client: client,
            transcriptStore: transcriptStore,
            agentOverrideID: agentOverrideID,
            localTranscriptLimit: localTranscriptLimit
        )

        screen.bindActions(
            sendCurrentDraft: { [weak self] in
                self?.sendCurrentDraft()
            },
            retryLastMessage: { [weak self] in
                self?.retryLastMessage()
            },
            startNewConversation: { [weak self] in
                self?.startNewConversation()
            },
            useSuggestion: { [weak self] prompt in
                self?.useSuggestion(prompt)
            }
        )
    }

    var messages: [ChatMessage] {
        screen.messages
    }

    var composerText: String {
        get { screen.composerText }
        set { screen.composerText = newValue }
    }

    var conversationID: String? {
        coordinator.conversationID
    }

    var activeAgentName: String {
        coordinator.activeAgentName
    }

    var inlineError: String? {
        screen.inlineError
    }

    var isStreaming: Bool {
        screen.isStreaming
    }

    var persistenceIssue: String? {
        screen.persistenceIssue
    }

    var canSendMessage: Bool {
        screen.canSendMessage
    }

    var scrollAnchorID: UUID? {
        screen.scrollAnchorID
    }

    var statusCaption: String {
        screen.statusCaption
    }

    func restoreIfNeeded() async {
        await coordinator.restoreIfNeeded(on: screen)
    }

    func sendCurrentDraft() {
        coordinator.sendCurrentDraft(from: screen)
    }

    func retryLastMessage() {
        coordinator.retryLastMessage(on: screen)
    }

    func startNewConversation() {
        coordinator.startNewConversation(on: screen)
    }

    func useSuggestion(_ prompt: String) {
        screen.composerText = prompt
        sendCurrentDraft()
    }

    func seedPreview(
        conversationID: String?,
        activeAgentName: String,
        messages: [ChatMessage],
        sendFailure: ChatScreenModel.SendFailure? = nil
    ) {
        coordinator.seedPreview(
            conversationID: conversationID,
            activeAgentName: activeAgentName,
            messages: messages,
            on: screen
        )
        screen.sendFailure = sendFailure
    }
}

@MainActor
private final class ChatSessionCoordinator {
    var conversationID: String?
    var activeAgentName = "Assistant"

    private let client: any ChatAPIClient
    private let transcriptStore: TranscriptStore
    private let agentOverrideID: String?
    private let logger = Logger(subsystem: "com.example.chatagent", category: "ChatSessionStore")
    private var sendTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private var pendingRetryMessage: String?
    private var hasRestoredSnapshot = false
    private let localTranscriptLimit: Int
    private var backendSessionHistoryLimit: Int?
    private var persistenceRevision = 0

    init(
        client: any ChatAPIClient,
        transcriptStore: TranscriptStore,
        agentOverrideID: String?,
        localTranscriptLimit: Int
    ) {
        self.client = client
        self.transcriptStore = transcriptStore
        self.agentOverrideID = agentOverrideID
        self.localTranscriptLimit = max(1, localTranscriptLimit)
    }

    static func defaultStatusCaption(for backendBaseURL: URL) -> String {
        if let host = backendBaseURL.host {
            return "Connected to \(host)"
        }
        return backendBaseURL.absoluteString
    }

    func restoreIfNeeded(on screen: ChatScreenModel) async {
        guard !hasRestoredSnapshot else { return }
        logger.info("restore_started")

        do {
            guard let snapshot = try await transcriptStore.load() else {
                hasRestoredSnapshot = true
                logger.info("restore_skipped reason=no_snapshot")
                return
            }
            logger.info(
                "restore_snapshot_loaded conversation_id=\((snapshot.conversationID ?? "none"), privacy: .private(mask: .hash)) message_count=\(snapshot.messages.count, privacy: .public)"
            )
            if let snapshotConversationID = snapshot.conversationID {
                do {
                    let status = try await client.conversationStatus(for: snapshotConversationID)
                    backendSessionHistoryLimit = max(1, status.sessionHistoryLimit)
                    guard status.exists else {
                        logger.notice(
                            "restore_missing_remote_conversation conversation_id=\(snapshotConversationID, privacy: .private(mask: .hash))"
                        )
                        logger.info(
                            "reset_started reason=missing_remote_conversation previous_conversation_id=\(snapshotConversationID, privacy: .private(mask: .hash))"
                        )
                        resetConversationState(on: screen)
                        screen.restoreIssue = .missingRemoteConversation
                        hasRestoredSnapshot = true
                        schedulePersistence(for: screen)
                        return
                    }
                } catch is CancellationError {
                    logger.info(
                        "restore_cancelled conversation_id=\(snapshotConversationID, privacy: .private(mask: .hash))"
                    )
                    return
                } catch {
                    logger.error(
                        "restore_verification_failed conversation_id=\(snapshotConversationID, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)"
                    )
                    restore(snapshot, needsConversationVerification: true, on: screen)
                    hasRestoredSnapshot = true
                    return
                }
            }

            restore(snapshot, on: screen)
            hasRestoredSnapshot = true
            logger.info(
                "restore_completed conversation_id=\((snapshot.conversationID ?? "none"), privacy: .private(mask: .hash))"
            )
        } catch is CancellationError {
            logger.info("restore_cancelled conversation_id=none")
            return
        } catch {
            hasRestoredSnapshot = true
            logger.error("restore_load_failed error=\(error.localizedDescription, privacy: .public)")
        }
    }

    func sendCurrentDraft(from screen: ChatScreenModel) {
        let trimmed = screen.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !screen.isStreaming else { return }
        screen.composerText = ""
        stream(message: trimmed, addUserBubble: true, on: screen)
    }

    func retryLastMessage(on screen: ChatScreenModel) {
        guard let pendingRetryMessage, !screen.isStreaming else { return }
        logger.info(
            "retry_started conversation_id=\((conversationID ?? "none"), privacy: .private(mask: .hash)) message_length=\(pendingRetryMessage.count, privacy: .public)"
        )
        screen.sendFailure = nil
        stream(message: pendingRetryMessage, addUserBubble: false, on: screen)
    }

    func startNewConversation(on screen: ChatScreenModel) {
        logger.info(
            "reset_started reason=manual previous_conversation_id=\((conversationID ?? "none"), privacy: .private(mask: .hash))"
        )
        sendTask?.cancel()
        sendTask = nil
        screen.isStreaming = false
        pendingRetryMessage = nil
        resetConversationState(on: screen)
        schedulePersistence(for: screen)
    }

    func seedPreview(
        conversationID: String?,
        activeAgentName: String,
        messages: [ChatMessage],
        on screen: ChatScreenModel
    ) {
        self.conversationID = conversationID
        self.activeAgentName = activeAgentName
        screen.activeAgentName = activeAgentName
        screen.restoreIssue = nil
        screen.sendFailure = nil
        screen.isStreaming = false
        screen.messages = messagesCapped(to: localTranscriptLimit, from: messages)
    }

    private func stream(message: String, addUserBubble: Bool, on screen: ChatScreenModel) {
        sendTask?.cancel()
        if screen.restoreIssue == .missingRemoteConversation {
            screen.restoreIssue = nil
        }
        logger.info(
            "stream_started conversation_id=\((conversationID ?? "none"), privacy: .private(mask: .hash)) add_user_bubble=\(addUserBubble, privacy: .public) message_length=\(message.count, privacy: .public)"
        )
        screen.sendFailure = nil
        pendingRetryMessage = message
        screen.isStreaming = true

        if addUserBubble {
            screen.messages.append(ChatMessage(role: .user, text: message))
        }

        let assistantID = UUID()
        screen.messages.append(ChatMessage(id: assistantID, role: .assistant, text: "", state: .streaming))
        schedulePersistence(for: screen)

        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                let request = BackendChatRequest(
                    message: message,
                    conversationID: self.conversationID,
                    agentID: self.agentOverrideID
                )
                var streamFailure: ChatScreenModel.SendFailure?
                for try await event in self.client.streamReply(for: request) {
                    if let failure = self.apply(event, assistantMessageID: assistantID, on: screen) {
                        streamFailure = failure
                        break
                    }
                }
                if let streamFailure {
                    self.finishStreamFailure(streamFailure, assistantMessageID: assistantID, on: screen)
                    return
                }
                if let index = screen.messages.firstIndex(where: { $0.id == assistantID }) {
                    screen.messages[index].state = .complete
                }
                self.pendingRetryMessage = nil
                screen.isStreaming = false
                screen.sendFailure = nil
                self.logger.info(
                    "stream_completed conversation_id=\((self.conversationID ?? "none"), privacy: .private(mask: .hash)) message_count=\(screen.messages.count, privacy: .public)"
                )
                self.schedulePersistence(for: screen)
            } catch is CancellationError {
                screen.isStreaming = false
                self.logger.info(
                    "stream_cancelled conversation_id=\((self.conversationID ?? "none"), privacy: .private(mask: .hash))"
                )
                self.schedulePersistence(for: screen)
            } catch {
                self.finishStreamFailure(
                    .transport(message: error.localizedDescription),
                    assistantMessageID: assistantID,
                    on: screen
                )
            }
        }
    }

    private func apply(
        _ event: ChatStreamEvent,
        assistantMessageID: UUID,
        on screen: ChatScreenModel
    ) -> ChatScreenModel.SendFailure? {
        switch event {
        case .conversationStarted(let payload):
            conversationID = payload.conversationID
            backendSessionHistoryLimit = max(1, payload.sessionHistoryLimit)
            screen.restoreIssue = nil
            return nil
        case .messageDelta(let payload):
            if let index = screen.messages.firstIndex(where: { $0.id == assistantMessageID }) {
                screen.messages[index].text += payload.delta
                screen.messages[index].state = .streaming
            }
            return nil
        case .agentUpdated(let payload):
            activeAgentName = payload.agentName
            screen.activeAgentName = payload.agentName
            return nil
        case .runItem(let payload):
            if payload.name == "tool_called" {
                activeAgentName = "Working..."
                screen.activeAgentName = "Working..."
            }
            return nil
        case .messageCompleted(let payload):
            conversationID = payload.conversationID
            activeAgentName = payload.finalAgentName
            backendSessionHistoryLimit = max(1, payload.sessionHistoryLimit)
            screen.activeAgentName = payload.finalAgentName
            screen.restoreIssue = nil
            if let index = screen.messages.firstIndex(where: { $0.id == assistantMessageID }) {
                screen.messages[index].text = payload.content
                screen.messages[index].state = .complete
            }
            return nil
        case .failure(let payload):
            return .backend(code: payload.code, message: payload.message)
        case .done:
            return nil
        }
    }

    private func schedulePersistence(for screen: ChatScreenModel) {
        persistenceRevision += 1
        let revision = persistenceRevision
        let snapshotMessages = messagesCapped(to: effectivePersistenceLimit, from: screen.messages)
        let snapshot = snapshotMessages.isEmpty
            ? nil
            : ConversationSnapshot(
                conversationID: conversationID,
                activeAgentName: activeAgentName,
                messages: snapshotMessages
            )

        persistenceTask?.cancel()
        persistenceTask = Task { [weak screen, transcriptStore, logger] in
            do {
                try await transcriptStore.replace(snapshot: snapshot, revision: revision)
                await MainActor.run {
                    screen?.persistenceIssue = nil
                }
            } catch is CancellationError {
                return
            } catch {
                logger.error("Transcript persistence failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    screen?.persistenceIssue = "Transcript persistence failed."
                }
            }
        }
    }

    private var effectiveRestoreLimit: Int {
        min(localTranscriptLimit, backendSessionHistoryLimit ?? localTranscriptLimit)
    }

    private var effectivePersistenceLimit: Int {
        min(localTranscriptLimit, backendSessionHistoryLimit ?? localTranscriptLimit)
    }

    private func messagesCapped(to limit: Int, from source: [ChatMessage]) -> [ChatMessage] {
        Array(source.suffix(limit))
    }

    private func restore(
        _ snapshot: ConversationSnapshot,
        needsConversationVerification: Bool = false,
        on screen: ChatScreenModel
    ) {
        conversationID = snapshot.conversationID
        activeAgentName = snapshot.activeAgentName
        screen.activeAgentName = snapshot.activeAgentName
        screen.sendFailure = nil
        screen.messages = messagesCapped(to: effectiveRestoreLimit, from: snapshot.messages)
        screen.restoreIssue = needsConversationVerification ? .unverifiedConversation : nil
    }

    private func resetConversationState(on screen: ChatScreenModel) {
        conversationID = nil
        backendSessionHistoryLimit = nil
        activeAgentName = "Assistant"
        screen.activeAgentName = "Assistant"
        screen.restoreIssue = nil
        screen.sendFailure = nil
        screen.messages.removeAll(keepingCapacity: true)
    }

    private func finishStreamFailure(
        _ failure: ChatScreenModel.SendFailure,
        assistantMessageID: UUID,
        on screen: ChatScreenModel
    ) {
        screen.isStreaming = false
        screen.sendFailure = failure
        if let index = screen.messages.firstIndex(where: { $0.id == assistantMessageID }) {
            if screen.messages[index].text.isEmpty {
                screen.messages.remove(at: index)
            } else {
                screen.messages[index].state = .failed
            }
        }
        switch failure {
        case .backend(let code, let message):
            logger.error(
                "stream_failed conversation_id=\((conversationID ?? "none"), privacy: .private(mask: .hash)) kind=\(failure.logKind, privacy: .public) code=\(code, privacy: .public) detail=\(message, privacy: .public)"
            )
        case .transport(let message):
            logger.error(
                "stream_failed conversation_id=\((conversationID ?? "none"), privacy: .private(mask: .hash)) kind=\(failure.logKind, privacy: .public) detail=\(message, privacy: .public)"
            )
        }
        schedulePersistence(for: screen)
    }
}
