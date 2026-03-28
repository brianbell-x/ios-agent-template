import Foundation
import XCTest
@testable import ChatSessionSupport

@MainActor
final class ChatSessionStoreRestoreTests: XCTestCase {
    func testRestoreUsesSnapshotWhenConversationStillExists() async throws {
        let harness = try await makeHarness()

        let store = ChatSessionStore(
            client: StubChatAPIClient {
                ConversationStatusPayload(
                    conversationID: harness.snapshot.conversationID ?? "",
                    exists: true,
                    sessionHistoryLimit: 40
                )
            },
            transcriptStore: harness.transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 40
        )

        await store.restoreIfNeeded()

        XCTAssertEqual(store.conversationID, harness.snapshot.conversationID)
        XCTAssertEqual(store.activeAgentName, harness.snapshot.activeAgentName)
        XCTAssertEqual(store.messages, harness.snapshot.messages)
        XCTAssertNil(store.inlineError)
        XCTAssertEqual(store.statusCaption, "Connected to example.com")
        XCTAssertEqual(try await harness.transcriptStore.load(), harness.snapshot)
    }

    func testRestoreKeepsLocalTranscriptLimitWhenBackendAllowsMoreHistory() async throws {
        let transcriptStore = try makeTranscriptStore()
        let snapshotMessages = [
            ChatMessage(role: .assistant, text: "One", createdAt: Date(timeIntervalSince1970: 1)),
            ChatMessage(role: .user, text: "Two", createdAt: Date(timeIntervalSince1970: 2)),
            ChatMessage(role: .assistant, text: "Three", createdAt: Date(timeIntervalSince1970: 3)),
            ChatMessage(role: .user, text: "Four", createdAt: Date(timeIntervalSince1970: 4)),
        ]
        let snapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: snapshotMessages
        )
        try await transcriptStore.replace(snapshot: snapshot, revision: 1)

        let store = ChatSessionStore(
            client: StubChatAPIClient {
                ConversationStatusPayload(
                    conversationID: "conversation-123",
                    exists: true,
                    sessionHistoryLimit: 10
                )
            },
            transcriptStore: transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 2
        )

        await store.restoreIfNeeded()

        XCTAssertEqual(store.conversationID, "conversation-123")
        XCTAssertEqual(store.messages, Array(snapshotMessages.suffix(2)))
        XCTAssertNil(store.inlineError)
    }

    func testRestoreUsesBackendSessionHistoryLimitWhenItIsLowerThanLocalTranscriptLimit() async throws {
        let transcriptStore = try makeTranscriptStore()
        let snapshotMessages = [
            ChatMessage(role: .assistant, text: "One", createdAt: Date(timeIntervalSince1970: 1)),
            ChatMessage(role: .user, text: "Two", createdAt: Date(timeIntervalSince1970: 2)),
            ChatMessage(role: .assistant, text: "Three", createdAt: Date(timeIntervalSince1970: 3)),
            ChatMessage(role: .user, text: "Four", createdAt: Date(timeIntervalSince1970: 4)),
        ]
        let snapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: snapshotMessages
        )
        try await transcriptStore.replace(snapshot: snapshot, revision: 1)

        let store = ChatSessionStore(
            client: StubChatAPIClient {
                ConversationStatusPayload(
                    conversationID: "conversation-123",
                    exists: true,
                    sessionHistoryLimit: 3
                )
            },
            transcriptStore: transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 5
        )

        await store.restoreIfNeeded()

        XCTAssertEqual(store.conversationID, "conversation-123")
        XCTAssertEqual(store.activeAgentName, "Planning Specialist")
        XCTAssertEqual(store.messages, Array(snapshotMessages.suffix(3)))
        XCTAssertEqual(store.messages.count, 3)
        XCTAssertNil(store.inlineError)
    }

    func testRestoreResetsAndClearsSnapshotWhenConversationIsMissing() async throws {
        let harness = try await makeHarness()

        let store = ChatSessionStore(
            client: StubChatAPIClient {
                ConversationStatusPayload(
                    conversationID: harness.snapshot.conversationID ?? "",
                    exists: false,
                    sessionHistoryLimit: 40
                )
            },
            transcriptStore: harness.transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 40
        )

        await store.restoreIfNeeded()

        XCTAssertNil(store.conversationID)
        XCTAssertEqual(store.activeAgentName, "Assistant")
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertEqual(
            store.inlineError,
            "The previous backend session is no longer available. Starting a new conversation."
        )
        XCTAssertEqual(store.statusCaption, "Connected to example.com")
        try await assertEventuallyEqual(ConversationSnapshot?.none) {
            try await harness.transcriptStore.load()
        }
    }

    func testRestorePreservesSnapshotWhenConversationStatusThrows() async throws {
        let harness = try await makeHarness()

        let store = ChatSessionStore(
            client: StubChatAPIClient {
                throw URLError(.notConnectedToInternet)
            },
            transcriptStore: harness.transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 40
        )

        await store.restoreIfNeeded()

        XCTAssertEqual(store.conversationID, harness.snapshot.conversationID)
        XCTAssertEqual(store.activeAgentName, harness.snapshot.activeAgentName)
        XCTAssertEqual(store.messages, harness.snapshot.messages)
        XCTAssertNil(store.inlineError)
        XCTAssertEqual(store.statusCaption, "Session unverified")
        XCTAssertEqual(try await harness.transcriptStore.load(), harness.snapshot)
    }

    func testSendPersistsStreamingAndCompletedSnapshots() async throws {
        let transcriptStore = try makeTranscriptStore()
        let controller = StreamController()

        let store = ChatSessionStore(
            client: StubChatAPIClient(streamReply: { request in
                controller.stream(for: request)
            }),
            transcriptStore: transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 40
        )

        store.composerText = "Plan lunch."
        store.sendCurrentDraft()

        try await assertEventuallyEqual(1) {
            controller.requestCount
        }

        XCTAssertEqual(controller.recordedRequests.first?.message, "Plan lunch.")
        XCTAssertNil(controller.recordedRequests.first?.conversationID)
        XCTAssertNil(controller.recordedRequests.first?.agentID)
        XCTAssertTrue(store.isStreaming)
        XCTAssertEqual(store.composerText, "")
        XCTAssertNil(store.inlineError)
        XCTAssertEqual(store.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(store.messages.last?.state, .streaming)

        let streamingSnapshot = ConversationSnapshot(
            conversationID: nil,
            activeAgentName: "Assistant",
            messages: store.messages
        )
        try await assertEventuallyEqual(streamingSnapshot) {
            try await transcriptStore.load()
        }

        controller.yield(
            .conversationStarted(
                ConversationStartedPayload(
                    conversationID: "conversation-123",
                    agentID: "planner",
                    sessionHistoryLimit: 40
                )
            ),
            at: 0
        )
        controller.yield(
            .agentUpdated(
                AgentUpdatedPayload(agentName: "Planning Specialist")
            ),
            at: 0
        )
        controller.yield(
            .messageDelta(
                MessageDeltaPayload(delta: "Working on it")
            ),
            at: 0
        )
        controller.yield(
            .messageCompleted(
                MessageCompletedPayload(
                    conversationID: "conversation-123",
                    agentID: "planner",
                    finalAgentName: "Planning Specialist",
                    responseID: "response-123",
                    content: "Here is the lunch plan.",
                    sessionHistoryLimit: 40
                )
            ),
            at: 0
        )
        controller.yield(.done, at: 0)
        controller.finish(at: 0)

        try await assertEventuallyEqual(false) {
            store.isStreaming
        }

        XCTAssertEqual(store.conversationID, "conversation-123")
        XCTAssertEqual(store.activeAgentName, "Planning Specialist")
        XCTAssertEqual(store.statusCaption, "Connected to example.com")
        XCTAssertNil(store.inlineError)
        XCTAssertEqual(store.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(store.messages.last?.text, "Here is the lunch plan.")
        XCTAssertEqual(store.messages.last?.state, .complete)

        let completedSnapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: store.messages
        )
        try await assertEventuallyEqual(completedSnapshot) {
            try await transcriptStore.load()
        }
    }

    func testSendPersistsLocalTranscriptLimitWhenBackendAllowsMoreHistory() async throws {
        let transcriptStore = try makeTranscriptStore()
        let controller = StreamController()
        let snapshotMessages = [
            ChatMessage(role: .assistant, text: "One", createdAt: Date(timeIntervalSince1970: 1)),
            ChatMessage(role: .user, text: "Two", createdAt: Date(timeIntervalSince1970: 2)),
            ChatMessage(role: .assistant, text: "Three", createdAt: Date(timeIntervalSince1970: 3)),
            ChatMessage(role: .user, text: "Four", createdAt: Date(timeIntervalSince1970: 4)),
        ]
        let snapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: snapshotMessages
        )
        try await transcriptStore.replace(snapshot: snapshot, revision: 1)

        let store = ChatSessionStore(
            client: StubChatAPIClient(
                status: { conversationID in
                    ConversationStatusPayload(
                        conversationID: conversationID,
                        exists: true,
                        sessionHistoryLimit: 10
                    )
                },
                streamReply: { request in
                    controller.stream(for: request)
                }
            ),
            transcriptStore: transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 3
        )

        await store.restoreIfNeeded()
        XCTAssertEqual(store.messages, Array(snapshotMessages.suffix(3)))

        store.composerText = "Keep going."
        store.sendCurrentDraft()

        try await assertEventuallyEqual(1) {
            controller.requestCount
        }

        XCTAssertEqual(controller.recordedRequests.first?.conversationID, "conversation-123")
        XCTAssertNil(controller.recordedRequests.first?.agentID)
        XCTAssertEqual(store.messages.count, 5)

        let streamingSnapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: Array(store.messages.suffix(3))
        )
        try await assertEventuallyEqual(streamingSnapshot) {
            try await transcriptStore.load()
        }

        controller.yield(
            .messageCompleted(
                MessageCompletedPayload(
                    conversationID: "conversation-123",
                    agentID: "planner",
                    finalAgentName: "Planning Specialist",
                    responseID: "response-123",
                    content: "Here is the next step.",
                    sessionHistoryLimit: 10
                )
            ),
            at: 0
        )
        controller.yield(.done, at: 0)
        controller.finish(at: 0)

        try await assertEventuallyEqual(false) {
            store.isStreaming
        }

        XCTAssertEqual(store.messages.count, 5)

        let completedSnapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: Array(store.messages.suffix(3))
        )
        try await assertEventuallyEqual(completedSnapshot) {
            try await transcriptStore.load()
        }
        XCTAssertEqual(completedSnapshot.messages.count, 3)
        XCTAssertEqual(completedSnapshot.messages.map(\.text), ["Four", "Keep going.", "Here is the next step."])
    }

    func testSendFailureKeepsInlineErrorAndRetryPath() async throws {
        let transcriptStore = try makeTranscriptStore()
        let controller = StreamController()

        let store = ChatSessionStore(
            client: StubChatAPIClient(
                streamReply: { request in
                    controller.stream(for: request)
                }
            ),
            transcriptStore: transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 40
        )

        store.composerText = "Draft a reply."
        store.sendCurrentDraft()

        try await assertEventuallyEqual(1) {
            controller.requestCount
        }

        controller.yield(
            .failure(
                StreamErrorPayload(
                    code: "backend_error",
                    message: "The backend could not complete the request."
                )
            ),
            at: 0
        )
        controller.finish(at: 0)

        try await assertEventuallyEqual(false) {
            store.isStreaming
        }

        XCTAssertEqual(controller.recordedRequests.first?.message, "Draft a reply.")
        XCTAssertNil(controller.recordedRequests.first?.agentID)
        XCTAssertEqual(store.statusCaption, "Connected to example.com")
        XCTAssertEqual(store.inlineError, "The backend could not complete the request.")
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages.first?.role, .user)

        let failedSnapshot = ConversationSnapshot(
            conversationID: nil,
            activeAgentName: "Assistant",
            messages: store.messages
        )
        try await assertEventuallyEqual(failedSnapshot) {
            try await transcriptStore.load()
        }

        store.retryLastMessage()

        try await assertEventuallyEqual(2) {
            controller.requestCount
        }

        controller.yield(
            .failure(
                StreamErrorPayload(
                    code: "backend_error",
                    message: "The backend could not complete the request."
                )
            ),
            at: 1
        )
        controller.finish(at: 1)

        try await assertEventuallyEqual(false) {
            store.isStreaming
        }
    }

    func testRetryDoesNotDuplicateUserMessageAndPersistsSuccessfulReply() async throws {
        let transcriptStore = try makeTranscriptStore()
        let controller = StreamController()

        let store = ChatSessionStore(
            client: StubChatAPIClient(streamReply: { request in
                controller.stream(for: request)
            }),
            transcriptStore: transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            localTranscriptLimit: 40
        )

        store.composerText = "Draft a reply."
        store.sendCurrentDraft()

        try await assertEventuallyEqual(1) {
            controller.requestCount
        }
        controller.yield(
            .failure(
                StreamErrorPayload(
                    code: "backend_error",
                    message: "The backend could not complete the request."
                )
            ),
            at: 0
        )
        controller.finish(at: 0)

        try await assertEventuallyEqual(false) {
            store.isStreaming
        }

        let firstUserMessage = try XCTUnwrap(store.messages.first)

        store.retryLastMessage()

        try await assertEventuallyEqual(2) {
            controller.requestCount
        }

        XCTAssertEqual(controller.recordedRequests.map(\.message), ["Draft a reply.", "Draft a reply."])
        XCTAssertEqual(controller.recordedRequests.map(\.conversationID), [nil, nil])
        XCTAssertEqual(controller.recordedRequests.map(\.agentID), [nil, nil])
        XCTAssertTrue(store.isStreaming)
        XCTAssertNil(store.inlineError)
        XCTAssertEqual(store.messages.count, 2)
        XCTAssertEqual(store.messages.filter { $0.role == .user }.count, 1)
        XCTAssertEqual(store.messages.first?.id, firstUserMessage.id)
        XCTAssertEqual(store.messages.last?.state, .streaming)

        let retryStreamingSnapshot = ConversationSnapshot(
            conversationID: nil,
            activeAgentName: "Assistant",
            messages: store.messages
        )
        try await assertEventuallyEqual(retryStreamingSnapshot) {
            try await transcriptStore.load()
        }

        controller.yield(
            .conversationStarted(
                ConversationStartedPayload(
                    conversationID: "conversation-123",
                    agentID: "planner",
                    sessionHistoryLimit: 40
                )
            ),
            at: 1
        )
        controller.yield(
            .messageCompleted(
                MessageCompletedPayload(
                    conversationID: "conversation-123",
                    agentID: "planner",
                    finalAgentName: "Planning Specialist",
                    responseID: "response-456",
                    content: "Retried reply.",
                    sessionHistoryLimit: 40
                )
            ),
            at: 1
        )
        controller.yield(.done, at: 1)
        controller.finish(at: 1)

        try await assertEventuallyEqual(false) {
            store.isStreaming
        }

        XCTAssertNil(store.inlineError)
        XCTAssertEqual(store.conversationID, "conversation-123")
        XCTAssertEqual(store.activeAgentName, "Planning Specialist")
        XCTAssertEqual(store.messages.count, 2)
        XCTAssertEqual(store.messages.first?.id, firstUserMessage.id)
        XCTAssertEqual(store.messages.last?.text, "Retried reply.")
        XCTAssertEqual(store.messages.last?.state, .complete)

        let completedSnapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: store.messages
        )
        try await assertEventuallyEqual(completedSnapshot) {
            try await transcriptStore.load()
        }
    }

    func testSendIncludesAgentOverrideWhenConfigured() async throws {
        let transcriptStore = try makeTranscriptStore()
        let controller = StreamController()

        let store = ChatSessionStore(
            client: StubChatAPIClient(streamReply: { request in
                controller.stream(for: request)
            }),
            transcriptStore: transcriptStore,
            backendBaseURL: URL(string: "https://example.com")!,
            agentOverrideID: "planner",
            localTranscriptLimit: 40
        )

        store.composerText = "Route this to the planner."
        store.sendCurrentDraft()

        try await assertEventuallyEqual(1) {
            controller.requestCount
        }

        XCTAssertEqual(controller.recordedRequests.first?.message, "Route this to the planner.")
        XCTAssertEqual(controller.recordedRequests.first?.agentID, "planner")
    }

    private func makeTranscriptStore() throws -> TranscriptStore {
        let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return TranscriptStore(fileURL: directoryURL.appending(path: "chat_snapshot.json"))
    }

    private func makeHarness() async throws -> RestoreHarness {
        let transcriptStore = try makeTranscriptStore()
        let snapshot = ConversationSnapshot(
            conversationID: "conversation-123",
            activeAgentName: "Planning Specialist",
            messages: [
                ChatMessage(
                    role: .assistant,
                    text: "Welcome back.",
                    createdAt: Date(timeIntervalSince1970: 1)
                ),
                ChatMessage(
                    role: .user,
                    text: "Continue the itinerary.",
                    createdAt: Date(timeIntervalSince1970: 2)
                ),
            ]
        )
        try await transcriptStore.replace(snapshot: snapshot, revision: 1)

        return RestoreHarness(transcriptStore: transcriptStore, snapshot: snapshot)
    }

    private func assertEventuallyEqual<T: Equatable>(
        _ expected: T,
        retries: Int = 20,
        value: () async throws -> T
    ) async throws {
        for attempt in 0..<retries {
            if try await value() == expected {
                return
            }
            if attempt < retries - 1 {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        XCTFail("Timed out waiting for expected value.")
    }
}

private struct RestoreHarness {
    let transcriptStore: TranscriptStore
    let snapshot: ConversationSnapshot
}

private struct StubChatAPIClient: ChatAPIClient {
    private let status: (String) async throws -> ConversationStatusPayload
    private let streamReplyHandler: (BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>

    init(
        status: @escaping (String) async throws -> ConversationStatusPayload = { conversationID in
            ConversationStatusPayload(
                conversationID: conversationID,
                exists: true,
                sessionHistoryLimit: 40
            )
        },
        streamReply: @escaping (BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> = { _ in
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }
    ) {
        self.status = status
        self.streamReplyHandler = streamReply
    }

    init(status: @escaping (String) async throws -> ConversationStatusPayload) {
        self.init(status: status, streamReply: { _ in
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        })
    }

    init(_ status: @escaping () async throws -> ConversationStatusPayload) {
        self.init(status: { _ in try await status() })
    }

    func streamReply(for request: BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        streamReplyHandler(request)
    }

    func conversationStatus(for conversationID: String) async throws -> ConversationStatusPayload {
        try await status(conversationID)
    }
}

private final class StreamController: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [BackendChatRequest] = []
    private var continuations: [AsyncThrowingStream<ChatStreamEvent, Error>.Continuation] = []

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    var recordedRequests: [BackendChatRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func stream(for request: BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        lock.lock()
        requests.append(request)
        lock.unlock()

        return AsyncThrowingStream { continuation in
            self.lock.lock()
            self.continuations.append(continuation)
            self.lock.unlock()
        }
    }

    func yield(_ event: ChatStreamEvent, at index: Int) {
        continuation(at: index)?.yield(event)
    }

    func finish(at index: Int) {
        continuation(at: index)?.finish()
    }

    private func continuation(
        at index: Int
    ) -> AsyncThrowingStream<ChatStreamEvent, Error>.Continuation? {
        lock.lock()
        defer { lock.unlock() }
        guard continuations.indices.contains(index) else { return nil }
        return continuations[index]
    }
}
