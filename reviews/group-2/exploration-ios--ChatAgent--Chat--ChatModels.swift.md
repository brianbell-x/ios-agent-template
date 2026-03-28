# Exploration Report

## Scope

- `Anchor File:` [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift)
- `Related Files Reviewed:`
  [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift),
  [ios/ChatAgent/Chat/ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift),
  [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift),
  [ios/ChatAgent/Chat/ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift),
  [ios/ChatAgent/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift),
  [ios/ChatAgent/App/AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift),
  [ios/Package.swift](/C:/dev/ios-agent-template/ios/Package.swift),
  [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift),
  [backend/app/schemas/chat.py](/C:/dev/ios-agent-template/backend/app/schemas/chat.py),
  [backend/app/agents/service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py),
  [shared/chat-stream-contract.json](/C:/dev/ios-agent-template/shared/chat-stream-contract.json),
  [shared/chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse),
  [docs/architecture.md](/C:/dev/ios-agent-template/docs/architecture.md)
- `Intent Context:` Review against a reusable iOS chat app foundation, not a one-off demo. Prioritize maintainability, clear boundaries, and a generic chat-first UX. Backend behavior should remain configurable without frontend rewrites. Avoid feature bloat and unnecessary abstraction.
- `Code Evidence Boundary:` No additional intent was inferred. Exploration stopped after the anchor file, its direct iOS consumers, the backend producers of the same payloads, and the narrow shared/test artifacts that define the same stream contract.

## Anchor Responsibilities

- Defines the persisted transcript entity shape with [ChatMessage](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L14), [ChatRole](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L3), [ChatMessageState](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L8), and [ConversationSnapshot](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L36).
- Defines the outbound backend request surface with [BackendChatRequest](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42).
- Defines every decoded backend transport payload used by the live chat flow, including conversation lifecycle, deltas, run items, completion, errors, and status in [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L54).
- Defines the client-side event enum that the SSE parser and session store coordinate through in [ChatStreamEvent](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L123).

## Engineering Decisions Found

### Decision 1: Use a two-role, plain-text transcript model and keep agent/tool activity outside the message list

- `Decision:` Represent transcript history as `ChatMessage(role, text, createdAt, state)` with only `user` and `assistant` roles, while handling `agent.updated` and `run.item` as separate session-store state instead of transcript entries.
- `Why Review It:` This is the core UI and persistence boundary for the reusable client. It determines whether richer backend behavior can surface without adding new frontend message types, view branches, and persistence schema changes.
- `Primary Lenses:` structure, simplicity
- `Evidence:` [ChatRole](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L3) only supports `user` and `assistant`; [ChatMessage](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L14) stores only text plus message state; [ChatSessionStore.apply](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164) maps `agentUpdated` to `activeAgentName` and special-cases `runItem` by setting `"Working..."` instead of creating transcript records; [MessageBubble](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L93) renders only text bubbles labeled `"You"` or `"Assistant"`; the backend emits both `agent.updated` and `run.item` in [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L106).
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift), [backend/app/agents/service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py)

### Decision 2: Maintain the chat stream contract as parallel manual schemas across Swift, Python, shared artifacts, and tests

- `Decision:` Hand-maintain equivalent stream/status/request payload definitions in Swift models and parser logic, backend Pydantic schemas and emitters, shared contract artifacts, and parser-fixture tests instead of deriving them from one authoritative contract source.
- `Why Review It:` This makes the chat boundary easy to read locally, but it expands the synchronization surface for every payload or event change and pushes contract drift detection into runtime failures or fixture upkeep.
- `Primary Lenses:` simplicity, structure, operability
- `Evidence:` [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42) defines the Swift request and event payloads; [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L39) hard-codes the same event names; [chat.py](/C:/dev/ios-agent-template/backend/app/schemas/chat.py#L45) defines the backend status and stream schemas; [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L80) emits the same event names and fields by hand; [chat-stream-contract.json](/C:/dev/ios-agent-template/shared/chat-stream-contract.json#L1) repeats the stream schema as a shared artifact; [chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse#L1) repeats the sample event sequence; [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L29) asserts the fixture against the Swift event models.
- `Related Files:` [ios/ChatAgent/Chat/ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift), [backend/app/schemas/chat.py](/C:/dev/ios-agent-template/backend/app/schemas/chat.py), [backend/app/agents/service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py), [shared/chat-stream-contract.json](/C:/dev/ios-agent-template/shared/chat-stream-contract.json), [shared/chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse), [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift)

### Decision 3: Keep a locally persisted conversation snapshot alongside backend-managed session state

- `Decision:` Persist `conversationID`, `activeAgentName`, and capped local messages as `ConversationSnapshot`, then restore that snapshot on launch and reconcile it with backend session existence through `GET /api/conversations/{conversation_id}`.
- `Why Review It:` This sets the recovery and ownership model for the app foundation. It creates a deliberate split between backend session memory and client-side cached transcript state, which is important to review for maintainability and failure recovery behavior.
- `Primary Lenses:` structure, operability, simplicity
- `Evidence:` [ConversationSnapshot](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L36) persists only conversation id, active agent name, and messages; [TranscriptStore](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L21) saves and loads that snapshot from disk; [ChatSessionStore.restoreIfNeeded](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60) reloads the snapshot, checks `conversationStatus`, and restores the local transcript if the conversation still exists; [ChatSessionStore.schedulePersistence](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195) rewrites the local snapshot after chat mutations; [docs/architecture.md](/C:/dev/ios-agent-template/docs/architecture.md#L53) documents the same split session strategy.
- `Related Files:` [ios/ChatAgent/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [docs/architecture.md](/C:/dev/ios-agent-template/docs/architecture.md)

### Decision 4: Let backend session and agent metadata directly drive client-side policy and UI state

- `Decision:` Include `agent_id`, `final_agent_name`, and `session_history_limit` in client transport models and use those values inside the session store to drive transcript trimming, restored-state limits, and status/agent display state.
- `Why Review It:` This defines how tightly the generic client is coupled to backend runtime policy. The same transport models are carrying both content and operational metadata, so changes in backend session behavior or agent identity handling may propagate into client state logic.
- `Primary Lenses:` structure, operability
- `Evidence:` [ConversationStartedPayload](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L54), [MessageCompletedPayload](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L88), and [ConversationStatusPayload](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L111) all embed session or agent metadata; [ChatSessionStore.restoreIfNeeded](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L66) and [ChatSessionStore.apply](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L166) use `sessionHistoryLimit` and agent names to mutate client behavior; [AppEnvironment](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3) separately injects a `defaultAgentID` and a fallback local transcript limit; the backend explicitly emits the same fields in [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L80).
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/App/AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift), [backend/app/agents/service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py)

## Coverage Gaps

- I did not inspect broader app wiring beyond the files that directly consume or produce the anchor models.
- I read the parser test and shared fixture, but I did not run `swift test`, Xcode builds, or backend tests during this exploration.
- Within the inspected iOS scope, I did not find direct automated tests for `ChatSessionStore` restore/persistence behavior or for iOS handling of streamed `error` events; the only directly reviewed iOS test target was [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift).
