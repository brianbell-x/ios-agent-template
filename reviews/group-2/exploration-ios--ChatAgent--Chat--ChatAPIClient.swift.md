# Exploration Report

## Scope Definition

- Anchor File: `ios/ChatAgent/Chat/ChatAPIClient.swift`
- Related Files Reviewed:
- `ios/ChatAgent/Chat/ChatModels.swift`
- `ios/ChatAgent/Chat/ChatStreamParser.swift`
- `ios/ChatAgent/Chat/ChatSessionStore.swift`
- `ios/ChatAgent/App/AppEnvironment.swift`
- `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift`
- `backend/app/api/routes_chat.py`
- `backend/app/agents/service.py`
- `backend/app/schemas/chat.py`
- `backend/app/streaming.py`
- `shared/openapi.json`
- `docs/architecture.md`
- Intent Context:
- Review against a reusable iOS chat app foundation, not a one-off demo.
- Prioritize maintainability, clear boundaries, and a generic chat-first UX.
- Backend behavior should remain configurable without frontend rewrites.
- Avoid feature bloat and unnecessary abstraction.

## Anchor Responsibilities

- Define the iOS chat transport boundary through `ChatAPIClient`.
- Fetch restore-time conversation validity from `GET /api/conversations/{conversation_id}`.
- Stream chat replies from `POST /api/chat/stream` with `URLSession.bytes`.
- Translate SSE lines into `ChatStreamEvent` values through `ChatStreamParser`.
- Collapse transport and stream failures into `ChatAPIError` values consumed by `ChatSessionStore`.

## Code Evidence Summary

- `LiveChatAPIClient` is the only live network client injected into the app environment and consumed by `ChatSessionStore`.
- The iOS layer hand-defines the request, status, and stream payload types that mirror the backend schemas and stream contract.
- The backend explicitly emits agent-routing and run-item SSE events, and the iOS state store uses them to shape visible UI status.
- Parser coverage exists against the shared fixture, but this scope does not include direct tests for `LiveChatAPIClient`, restore validation, or HTTP-versus-SSE error handling.

## Engineering Decisions Found

### Decision 1: Frontend-owned transport contract

- `Decision:` Keep the iOS chat boundary hand-modeled in Swift with hardcoded `/api/chat/stream` and `/api/conversations/{conversation_id}` endpoints plus a local SSE parser instead of consuming a generated client or shared transport runtime.
- `Why Review It:` This keeps the surface small, but it also makes the reusable app foundation absorb backend contract drift, event-versioning changes, and duplicated schema maintenance inside the frontend layer that is supposed to stay generic.
- `Primary Lenses:` `simplicity`, `structure`
- `Evidence:` `ChatAPIClient` exposes only typed transport operations in `ios/ChatAgent/Chat/ChatAPIClient.swift:3-5`; `LiveChatAPIClient` hardcodes endpoint paths in `ios/ChatAgent/Chat/ChatAPIClient.swift:29-31` and `ios/ChatAgent/Chat/ChatAPIClient.swift:45-49`; the request and stream payloads are redefined locally in `ios/ChatAgent/Chat/ChatModels.swift:42-130`; `ChatStreamParser` switches on fixed SSE event names in `ios/ChatAgent/Chat/ChatStreamParser.swift:39-55`; the backend publishes matching HTTP and stream contracts in `shared/openapi.json:29-173` and `backend/app/streaming.py:28-90`.
- `Related Files:` `ios/ChatAgent/Chat/ChatModels.swift`, `ios/ChatAgent/Chat/ChatStreamParser.swift`, `shared/openapi.json`, `backend/app/streaming.py`

### Decision 2: UI state driven by backend execution events

- `Decision:` Use streamed `agent.updated` and `run.item` events to drive visible frontend status text, including a special-case `tool_called` to `"Working..."`.
- `Why Review It:` This pushes backend execution semantics into a generic chat UI. Changes in agent routing, tool naming, or handoff behavior can now force coordinated frontend updates even though backend behavior is meant to stay configurable without frontend rewrites.
- `Primary Lenses:` `structure`, `simplicity`, `operability`
- `Evidence:` The parser treats `agent.updated` and `run.item` as first-class events in `ios/ChatAgent/Chat/ChatStreamParser.swift:44-47`; `ChatSessionStore` maps `agent.updated` into `activeAgentName` and maps `run.item` named `tool_called` into `"Working..."` in `ios/ChatAgent/Chat/ChatSessionStore.swift:174-179`; the backend emits those envelopes from streamed runtime events in `backend/app/agents/service.py:106-120`.
- `Related Files:` `ios/ChatAgent/Chat/ChatSessionStore.swift`, `ios/ChatAgent/Chat/ChatStreamParser.swift`, `backend/app/agents/service.py`

### Decision 3: Restore path gated on live session validation

- `Decision:` Validate any restored `conversation_id` against the backend before reusing cached transcript state, and reset the local conversation when validation fails or reports `exists = false`.
- `Why Review It:` This establishes the app foundation's recovery model for offline use, backend restarts, and transient network failures. It also couples transcript restoration to backend availability instead of treating local history as independently useful UI state.
- `Primary Lenses:` `operability`, `structure`
- `Evidence:` `ChatSessionStore.restoreIfNeeded()` calls `client.conversationStatus` before restoring messages in `ios/ChatAgent/Chat/ChatSessionStore.swift:60-79`; the same method clears local state on both `exists == false` and thrown errors in `ios/ChatAgent/Chat/ChatSessionStore.swift:69-83`; the anchor exposes the restore-time validation call in `ios/ChatAgent/Chat/ChatAPIClient.swift:29-38`; the backend status response only reports existence and session limit in `backend/app/agents/service.py:135-140`.
- `Related Files:` `ios/ChatAgent/Chat/ChatSessionStore.swift`, `ios/ChatAgent/Chat/ChatAPIClient.swift`, `backend/app/agents/service.py`

### Decision 4: Split failure semantics across events and thrown errors

- `Decision:` Convert streamed `error` envelopes into thrown `ChatAPIError.server` values and non-2xx responses into generic `HTTP <code>` failures instead of surfacing one consistent typed failure model to callers.
- `Why Review It:` The live client and state store now straddle multiple error channels. `ChatSessionStore` still implements a `.failure` event path, but the live client never yields it, and pre-stream HTTP failures discard backend-provided error detail, which complicates debugging and recovery behavior.
- `Primary Lenses:` `operability`, `structure`, `simplicity`
- `Evidence:` `LiveChatAPIClient` maps non-2xx responses to `unacceptableStatusCode` in `ios/ChatAgent/Chat/ChatAPIClient.swift:35-36` and `ios/ChatAgent/Chat/ChatAPIClient.swift:55-56`; it throws on `.failure` before yielding the event in `ios/ChatAgent/Chat/ChatAPIClient.swift:61-64` and `ios/ChatAgent/Chat/ChatAPIClient.swift:69-72`; `ChatSessionStore.apply` still handles `.failure` as a stream event in `ios/ChatAgent/Chat/ChatSessionStore.swift:188-189`; the backend exposes structured HTTP and SSE error payloads in `backend/app/schemas/chat.py:27-34` and `backend/app/api/routes_chat.py:121-166`.
- `Related Files:` `ios/ChatAgent/Chat/ChatAPIClient.swift`, `ios/ChatAgent/Chat/ChatSessionStore.swift`, `backend/app/api/routes_chat.py`, `backend/app/schemas/chat.py`

## Coverage Gaps

- I did not inspect `ios/ChatAgent/Chat/ChatView.swift` or broader app navigation because `ChatSessionStore` was enough to understand the anchor's direct UI touch surface.
- I could not verify runtime behavior on a live iOS build or against a running backend from this Windows environment.
- In the inspected scope, I did not find direct tests for `LiveChatAPIClient`, restore-time validation behavior, or HTTP-versus-SSE error mapping; only the parser fixture path is covered by `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift`.
