# Exploration Report

## Scope

- `Anchor File:` [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift)
- `Related Files Reviewed:` [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift), [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift), [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift)
- `Intent Context:` Review against a reusable iOS chat app foundation, not a one-off demo. Prioritize maintainability, clear boundaries, and a generic chat-first UX. Backend behavior should remain configurable without frontend rewrites. Avoid feature bloat and unnecessary abstraction.

## Intent Context Versus Code Evidence

- `Intent Context:` The user explicitly framed this pass around reusability, maintainability, clear boundaries, backend configurability, and avoiding unnecessary abstraction.
- `Code Evidence:` [TranscriptStore.swift:3](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L3) owns local transcript persistence as an actor over a single optional file URL. [ChatSessionStore.swift:60](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60) is the sole restore/persist caller and couples that store to backend session checks, UI state, and retry/error handling. [ChatAgentApp.swift:33](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L33) runs restore on startup. [ChatView.swift:36](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L36) renders inline transport errors but not persistence-specific state.

## Anchor Responsibilities

- `TranscriptStore` constructs live and preview instances, chooses the Application Support file path, loads and decodes `ConversationSnapshot`, writes snapshots atomically, clears the persisted file, and suppresses stale writes with a monotonically increasing revision.
- The anchor directly touches the persisted snapshot schema in [ChatModels.swift:36](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L36) and the calling lifecycle in [ChatSessionStore.swift:195](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195).

## Engineering Decisions Found

### Decision 1: Backend validation gates transcript rehydration

- `Decision:` Use backend `conversationStatus` verification as part of startup restore, and reset local conversation state when verification fails or reports that the session no longer exists.
- `Why Review It:` This makes launch-time transcript restore depend on backend reachability and a specific backend contract, even though the local snapshot already exists on disk. It also folds local persistence recovery and server-session recovery into one path.
- `Primary Lenses:` structure, operability
- `Evidence:` [ChatSessionStore.swift:65](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L65) loads the snapshot, [ChatSessionStore.swift:67](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L67) calls `conversationStatus`, [ChatSessionStore.swift:69](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L69) resets state when the backend reports the conversation missing, [ChatSessionStore.swift:80](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L80) does the same on any thrown error, [ChatAPIClient.swift:29](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L29) implements that check as a live HTTP request, and [ChatAgentApp.swift:33](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L33) runs restore at app startup.
- `Related Files:` [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift)

### Decision 2: Persist the UI-facing transcript model directly as the on-disk contract

- `Decision:` Serialize `ConversationSnapshot` and `ChatMessage` directly to disk instead of introducing a persistence-specific schema or versioned storage contract.
- `Why Review It:` This keeps the implementation simple, but it makes local restore compatibility follow UI model evolution, including message state enums and agent-label semantics. That coupling is material in a reusable app foundation because frontend model changes become persistence-format changes.
- `Primary Lenses:` simplicity, structure, operability
- `Evidence:` [ChatModels.swift:14](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L14) defines `ChatMessage` as a Codable UI model, [ChatModels.swift:36](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L36) defines `ConversationSnapshot`, [TranscriptStore.swift:21](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L21) decodes that type directly, [TranscriptStore.swift:28](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L28) encodes it directly, [ChatSessionStore.swift:77](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L77) restores snapshot fields straight into live UI state, and [ChatSessionStore.swift:201](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L201) builds the persisted snapshot from current UI state.
- `Related Files:` [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)

### Decision 3: Coordinate persistence freshness through task cancellation plus in-memory revision checks

- `Decision:` Coalesce frequent transcript writes by canceling the previous persistence task in `ChatSessionStore` and letting `TranscriptStore` drop stale saves with an actor-local `newestRevision`.
- `Why Review It:` The concurrency and failure semantics are split across two types, so understanding which snapshot can win requires following both task cancellation and revision filtering. That is a meaningful local design choice for operability and later maintenance.
- `Primary Lenses:` structure, operability, scale
- `Evidence:` [ChatSessionStore.swift:195](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195) increments `persistenceRevision`, [ChatSessionStore.swift:207](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L207) cancels the previous task, [ChatSessionStore.swift:208](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L208) launches a detached persistence task, [TranscriptStore.swift:5](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L5) stores `newestRevision`, and [TranscriptStore.swift:45](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L45) drops older revisions before writing or clearing.
- `Related Files:` [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)

### Decision 4: Tie local transcript retention to backend session-history limits

- `Decision:` Use `transcriptLimit` as both the local persistence cap and the UI restore cap, while updating that limit from backend-provided `sessionHistoryLimit`.
- `Why Review It:` This couples local chat history retention to backend session policy rather than a separate frontend history decision. In a reusable chat foundation, that boundary matters because server context-window rules and local user-visible history are not necessarily the same concern.
- `Primary Lenses:` structure, simplicity, scale
- `Evidence:` [ChatSessionStore.swift:25](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L25) stores `transcriptLimit`, [ChatSessionStore.swift:39](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L39) seeds it from `localTranscriptLimit`, [ChatSessionStore.swift:68](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L68) updates it from `conversationStatus`, [ChatSessionStore.swift:168](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L168) and [ChatSessionStore.swift:183](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L183) update it from streaming events, [ChatSessionStore.swift:198](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L198) caps messages before persistence, and [ChatSessionStore.swift:225](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L225) uses the same cap for restore.
- `Related Files:` [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift)

### Decision 5: Surface persistence failures as internal store state and logs, not as part of the visible chat recovery flow

- `Decision:` Handle transcript persistence failures by logging them and storing a `persistenceIssue` flag in `ChatSessionStore`, while the chat UI only renders `inlineError`.
- `Why Review It:` This determines how easy local-storage issues are to detect, explain, and support. It is a distinct operability decision because persistence failure and response-stream failure follow different visibility paths.
- `Primary Lenses:` operability, structure
- `Evidence:` [ChatSessionStore.swift:14](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L14) defines `persistenceIssue`, [ChatSessionStore.swift:217](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L217) logs persistence failures, [ChatSessionStore.swift:219](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L219) stores the failure state, and [ChatView.swift:36](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L36) only renders `inlineError`.
- `Related Files:` [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift)

## Coverage Gaps

- No dedicated iOS tests were found for `TranscriptStore` or the `ChatSessionStore` persistence and restore path. The only iOS test file I located in the app tree was [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift).
- I did not inspect the backend server implementation behind `GET /api/conversations/:id`; only the iOS client contract in [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift) was read because backend server code is outside the anchor's direct touch surface.
- I did not run the iOS app, so startup timing, file-system behavior under the real sandbox, and live persistence failure behavior were assessed statically.
