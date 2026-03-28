# Decision Review

## Decision

- `Decision:` Use server-side `SQLiteSession` for canonical conversation memory, expose agent runs through backend SSE streaming, and pair that with a locally persisted transcript plus a custom SSE parser on the iOS client. Scope reviewed: the backend chat/session/stream path and the iOS transcript restore and stream-consumption path that implement this flow.
- `Scope Reviewed:` [backend/app/agents/service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py), [backend/app/api/routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py), [backend/app/core/config.py](/C:/dev/ios-agent-template/backend/app/core/config.py), [ios/ChatAgentTemplate/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatAPIClient.swift), [ios/ChatAgentTemplate/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatModels.swift), [ios/ChatAgentTemplate/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift), [ios/ChatAgentTemplate/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/TranscriptStore.swift)

## Evidence Reviewed

- `Code:` [backend/app/agents/service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py), [backend/app/api/routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py), [shared/openapi.json](/C:/dev/ios-agent-template/shared/openapi.json), [ios/ChatAgentTemplate/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatAPIClient.swift), [ios/ChatAgentTemplate/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatModels.swift), [ios/ChatAgentTemplate/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift), [ios/ChatAgentTemplate/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/TranscriptStore.swift)
- `Tests/Specs/Diffs:` [backend/tests/test_chat_service.py](/C:/dev/ios-agent-template/backend/tests/test_chat_service.py), [docs/architecture.md](/C:/dev/ios-agent-template/docs/architecture.md), [README.md](/C:/dev/ios-agent-template/README.md); no iOS-side tests were present for the stream parser or transcript restore path
- `Docs:` OpenAI Agents SDK Sessions docs, OpenAI Agents SDK Streaming docs, OpenAI Agents SDK Streaming Events reference

## Lens Check

- `Simplicity:` `SQLiteSession` plus SSE is a reasonable baseline, but the added local transcript cache creates a second memory system the template now has to keep coherent.
- `Structure:` Backend ownership of agent behavior is clear, but transcript state and the stream event contract are both duplicated across the Python and Swift layers.
- `Operability:` The main operational risk is silent divergence: the UI can restore one conversation view while the backend session history or streaming contract has drifted underneath it.
- `Scale:` There is a material growth issue because both the backend session and the local transcript store retain full history with no pruning or retrieval bound.

## Findings

### [medium] [structure] Dual sources of truth for one conversation

- `Evidence:` The backend treats `conversation_id` as the key for SDK-managed memory by constructing `SQLiteSession` on every turn in [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L47) and [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L65). The client separately restores and reuses a persisted `ConversationSnapshot` with `conversationID` and full `messages` in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift#L52), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift#L113), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift#L174), and [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/TranscriptStore.swift#L20). The architecture doc explicitly relies on the backend session so the client does not resend transcript history in [docs/architecture.md](/C:/dev/ios-agent-template/docs/architecture.md#L43).
- `Problem:` The design duplicates conversation semantics in two independent stores without any reconciliation step. A restored local transcript can outlive the server-side SQLite session, or point at a backend that has been reset, switched, or reconfigured, while the UI still presents the old conversation as authoritative.
- `Why It Matters:` This fails as confusing product behavior instead of a clean error. Users can see an apparently continuous chat while the backend answers with no prior context, and debugging becomes harder because both the client cache and the backend session look locally valid.
- `Better Direction:` Keep one authoritative conversation state. The smallest fix is to validate restored `conversation_id` values against the backend before reuse and clear the local snapshot on mismatch. If transcript restore is required, add a backend transcript/session-resume endpoint rather than assuming the local cache and server memory stay aligned forever.

### [medium] [scale] No history bound on either persistence layer

- `Evidence:` The backend always uses `SQLiteSession` with no `RunConfig.session_settings` or pruning callback in [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L47) and [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L65). The official Sessions docs state that, by default, session retrieval uses `SessionSettings(limit=None)` and therefore fetches all available session items before each run. The client also persists the full `messages` array on disk in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift#L174) and [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/TranscriptStore.swift#L27).
- `Problem:` Long conversations grow without any server-side retrieval limit, compaction strategy, or client-side snapshot cap. The same transcript is retained in memory, on disk in iOS, and in the backend SQLite store.
- `Why It Matters:` This is fine in short demos but degrades badly in real use: prompt assembly cost grows, latency and token spend rise, the SQLite file expands, and local restore payloads get larger over time. Because this is a starter template, shipping without a default bound bakes that cost into downstream apps.
- `Better Direction:` Set an explicit default history policy now. A small fix is to apply `SessionSettings(limit=...)` or a `session_input_callback` on the backend and mirror that same retention policy in the local transcript snapshot so both layers age out old content predictably.

### [low] [structure] The streaming contract is hand-maintained outside the shared API contract

- `Evidence:` The backend manually maps Agents SDK events into custom SSE event names and payloads in [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L70) and serializes them in [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L38). The iOS client duplicates those event names and payload types in [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatModels.swift#L54) and [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatAPIClient.swift#L76). The exported shared contract leaves `/api/chat/stream` effectively undocumented with an empty response schema in [shared/openapi.json](/C:/dev/ios-agent-template/shared/openapi.json#L90). The only automated coverage here is backend-side envelope sequencing in [test_chat_service.py](/C:/dev/ios-agent-template/backend/tests/test_chat_service.py#L64), and there are no iOS tests for the parser path.
- `Problem:` Every change to the stream payloads now requires manual coordination across Python, Swift models, the handwritten parser, and prose docs. The repo’s shared contract artifact does not describe that stream surface, so the most change-prone API in this decision is the least mechanically enforced.
- `Why It Matters:` This is a contained but real maintenance cost. Template consumers are likely to extend streamed event types first, and the failure mode is runtime breakage in the chat UI rather than an obvious compile-time or contract-test failure.
- `Better Direction:` Keep SSE if desired, but define a single documented event envelope and add contract tests on both sides. The smallest improvement is one shared stream fixture plus iOS parser tests so backend event changes fail in CI instead of on-device.

## Recommended Fix Actions

1. Add a backend-backed session resume check before the client reuses a restored `conversation_id`; if the session is missing or incompatible, clear the local snapshot and start a fresh conversation.
2. Add a default retention policy for long chats on the backend with `SessionSettings(limit=...)` or a pruning callback, and apply the same cap to the local transcript snapshot.
3. Document the SSE event envelope in one shared artifact and add at least one iOS parser test driven by a backend-produced stream fixture.

## Sources

- https://openai.github.io/openai-agents-python/sessions/
- https://openai.github.io/openai-agents-python/streaming/
- https://openai.github.io/openai-agents-python/ref/stream_events/
