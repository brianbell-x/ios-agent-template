# Exploration Report

## Scope

- `Anchor File:` [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)
- `Related Files Reviewed:` [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ios/ChatAgent/Chat/ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift), [ios/ChatAgent/App/AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift), [ios/ChatAgent/App/ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift)
- `Intent Context:` Review against a reusable iOS chat app foundation, not a one-off demo. Prioritize maintainability, clear boundaries, and a generic chat-first UX. Backend behavior should remain configurable without frontend rewrites. Avoid feature bloat and unnecessary abstraction.
- `Code Evidence Scope:` Limited to the anchor file and the files it directly imports, configures, or is invoked from. No broader repo review was performed.

## Anchor Responsibilities

- `ChatSessionStore` is the app-facing state holder for transcript data, composer text, session identifiers, inline error state, and persistence status in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L5).
- It restores persisted conversations, revalidates stored backend conversation IDs, drives streaming requests, applies stream events, and writes conversation snapshots in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60).
- The SwiftUI layer binds directly to its mutable state and imperative actions in [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L4) and [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L14).

## Engineering Decisions To Review Later

### Decision 1: One store owns UI state, transport lifecycle, restore logic, and snapshot persistence

- `Decision:` The foundation uses a single `@MainActor @Observable` `ChatSessionStore` as the ownership boundary for transcript view state, backend streaming orchestration, backend session validation, and local transcript persistence.
- `Why Review It:` This boundary determines where future agent, session, and persistence behavior must land. In a reusable foundation, it materially affects testability, change isolation, and whether responsibilities stay legible as the app grows.
- `Primary Lenses:` structure, simplicity
- `Evidence:` Public UI state and coordination fields live together in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L7); restore and backend validation are handled in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60); streaming request creation and event application are handled in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L115); persistence scheduling is also handled there in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195); the view binds directly to the store contract in [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L4).
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift)

### Decision 2: Every request is pinned to one environment-configured agent ID

- `Decision:` The frontend sends the same `defaultAgentID` on every request from app configuration, while backend agent updates only affect display text.
- `Why Review It:` This is a direct product-boundary choice for a reusable chat shell. It determines how much backend agent customization can remain configuration-driven without introducing new frontend seams or changing the client request contract later.
- `Primary Lenses:` structure, simplicity
- `Evidence:` The environment loads a single `ChatDefaultAgentID` value in [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L10); the store keeps that as immutable input in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L28); outbound requests always use `agentID: self.defaultAgentID` in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L132); the request model exposes only one optional `agent_id` field in [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42); streamed agent updates only change `activeAgentName` in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L174).
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/App/AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift), [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift)

### Decision 3: Local transcript retention is governed by backend session-history limits

- `Decision:` The store caps in-memory and persisted messages to the current `sessionHistoryLimit` reported by the backend and revalidates persisted conversation IDs with the backend before restoring them.
- `Why Review It:` This choice defines the client/backend boundary for conversation continuity. It affects what history survives app restarts, how local UX behaves when backend limits change, and whether client retention policy is intentionally delegated to the backend.
- `Primary Lenses:` structure, operability, scale
- `Evidence:` The store initializes a local cap from configuration in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L28); it replaces that cap with backend status data during restore in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L64); it updates the same cap from stream events in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L166); snapshots are truncated through `cappedMessages` in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195) and [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L225); persisted snapshots only contain `conversationID`, `activeAgentName`, and `messages` in [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L36); the transcript store persists a single snapshot file in [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L21).
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ios/ChatAgent/App/AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift)

### Decision 4: Send, cancellation, and retry are modeled as a single in-flight task plus one retry string

- `Decision:` The store cancels any existing send before starting another, tracks only one `pendingRetryMessage`, retries without re-adding the user bubble, and treats cancellation as a silent local state transition.
- `Why Review It:` This decision shapes how the chat surface behaves under interruption, retries, or future concurrency. It directly affects operability, UX determinism, and whether support or debugging has enough state to distinguish intentional cancels from transport failures.
- `Primary Lenses:` operability, simplicity, scale
- `Evidence:` The store owns one `sendTask` and one `pendingRetryMessage` in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L21); starting a new send cancels the old task in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L115); retries replay only the stored message string in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L94); cancellations only clear streaming state and persist in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L146); the UI exposes one inline error card and one retry action in [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L36) and [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L244).
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift)

### Decision 5: Failure semantics are split between stream events and thrown transport errors

- `Decision:` The stream contract models failure as both a `ChatStreamEvent.failure` case and a terminal thrown `ChatAPIError.server`, and the store retains handling paths for both.
- `Why Review It:` This is a local API-boundary decision with direct operability consequences. Duplicated failure channels can complicate client implementations, logging expectations, and later transport changes because not all failures are represented the same way at the store boundary.
- `Primary Lenses:` structure, operability
- `Evidence:` The shared event model includes a `.failure` case in [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L123); `LiveChatAPIClient` throws when the parser emits a failure payload instead of yielding that event in [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L59); `ChatSessionStore.apply` still has an explicit `.failure` branch in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164); separate thrown-error handling updates the same UI state in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L149).
- `Related Files:` [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)

## Coverage Gaps

- No direct tests for `ChatSessionStore`, `TranscriptStore`, or `LiveChatAPIClient` were found under [ios/Tests](/C:/dev/ios-agent-template/ios/Tests); only parser-focused coverage exists in [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift).
- Backend-side semantics for `session_history_limit`, `tool_called`, and conversation invalidation were not inspected because that would broaden beyond the anchor file's immediate touch surface.
- I did not inspect Info.plist or backend service code, so the configured values and endpoint behavior were treated as external inputs rather than verified implementation details.

## Notes

- This report inventories local engineering decisions only. It does not include final findings, severity calls, or fix actions.
