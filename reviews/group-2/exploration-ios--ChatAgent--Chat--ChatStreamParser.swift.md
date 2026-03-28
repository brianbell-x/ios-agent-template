# Exploration Report

## Scope

- `Anchor File:` [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L1)
- `Related Files Reviewed:` [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L1), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L1), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L150), [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L1), [Package.swift](/C:/dev/ios-agent-template/ios/Package.swift#L1), [streaming.py](/C:/dev/ios-agent-template/backend/app/streaming.py#L1), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L90), [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L101), [chat-stream-contract.json](/C:/dev/ios-agent-template/shared/chat-stream-contract.json), [chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse)
- `Intent Context:` Review against a reusable iOS chat app foundation, not a one-off demo. Prioritize maintainability, clear boundaries, and a generic chat-first UX. Backend behavior should remain configurable without frontend rewrites. Avoid feature bloat and unnecessary abstraction.

## Intent Context vs Code Evidence

- `Intent Context:` The frontend should stay generic while backend behavior remains configurable.
- `Code Evidence:` The parser is a narrow SSE adapter that hard-codes the current event catalog and payload shapes in Swift, then feeds those events directly into app state updates.
- `Intent Context:` Maintainability and clear boundaries matter more than demo-only speed.
- `Code Evidence:` The parser is isolated into a small Swift package target for tests, but the contract itself is still mirrored manually across backend, shared artifacts, and iOS types.

## Anchor Responsibilities

- Parse line-delimited SSE input into typed `ChatStreamEvent` values in [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L3).
- Maintain temporary event state across `event:` and `data:` lines until a blank line flushes the event in [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L8).
- Decode the known stream payload set defined in [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L54) and surfaced by [streaming.py](/C:/dev/ios-agent-template/backend/app/streaming.py#L28).
- Feed parsed events into the live networking path in [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L41), which then drives UI state changes in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164).

## Immediate Touch Surface

- [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L54) defines the Swift payloads and `ChatStreamEvent` cases the parser emits.
- [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L41) owns stream transport, parser invocation, and error propagation.
- [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164) interprets parsed events into transcript and status UI state.
- [streaming.py](/C:/dev/ios-agent-template/backend/app/streaming.py#L28), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L95), and [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L117) define and emit the backend stream contract the parser assumes.
- [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L5) covers only the exported happy-path fixture from [chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse).

## Engineering Decisions To Review

### Decision 1: Manual client-side mirroring of the backend stream contract

- `Decision:` The iOS client hard-codes the backend SSE event catalog and payload shapes in `ChatStreamParser` and `ChatModels` instead of consuming a generated shared contract.
- `Why Review It:` This file is part of a reusable app foundation, but backend stream evolution currently requires coordinated backend, shared-artifact, and iOS code changes. That raises maintenance cost and makes backend customization more likely to force frontend edits.
- `Primary Lenses:` structure, simplicity
- `Evidence:` [streaming.py](/C:/dev/ios-agent-template/backend/app/streaming.py#L28) declares the authoritative event names and schemas, while [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L39) repeats the event-name switch and [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L54) repeats the payload types. [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L6) validates against the exported fixture rather than a generated client contract.
- `Related Files:` [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L1), [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L54), [streaming.py](/C:/dev/ios-agent-template/backend/app/streaming.py#L28), [chat-stream-contract.json](/C:/dev/ios-agent-template/shared/chat-stream-contract.json), [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L5)

### Decision 2: Unknown SSE fields and events are treated as silent no-ops

- `Decision:` The parser only recognizes `event:` and `data:` lines and returns `nil` for any unrecognized event name, so unsupported stream data is silently dropped.
- `Why Review It:` Silent drops preserve a clean happy path, but they also hide contract drift and make debugging harder when the backend adds events for tools, handoffs, guardrails, or MCP-related status that the generic chat UI may eventually need.
- `Primary Lenses:` operability, structure
- `Evidence:` [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L13) ignores all line types except `event:` and `data:`, and [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L54) returns `nil` for unknown event names. [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L60) yields only non-`nil` parser results, so dropped events leave no explicit trace in the client path.
- `Related Files:` [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L8), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L59), [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L6)

### Decision 3: A single payload decode mismatch terminates the entire response stream

- `Decision:` Parsing and JSON decoding failures from `ChatStreamParser` are propagated as terminal stream errors rather than being isolated to the offending event.
- `Why Review It:` This keeps the implementation simple, but it makes the chat turn brittle. One payload mismatch can fail a partially streamed response and immediately push recovery burden into higher-level UI state handling.
- `Primary Lenses:` operability
- `Evidence:` [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L8) and [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L26) throw on parse/decode errors. [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L77) converts any parser error into `continuation.finish(throwing:)`. [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L150) then removes an empty assistant message or marks a partial one as failed.
- `Related Files:` [ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L8), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L41), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L150)

### Decision 4: Low-level run-item names leak directly into frontend UX behavior

- `Decision:` `run.item` is modeled as a loosely typed `name` and `item_type` payload, and the frontend interprets backend-specific names like `tool_called` directly to drive user-visible status text.
- `Why Review It:` This is a reusable chat foundation with configurable backend agents, tools, and handoffs. UI behavior tied to magic backend event names makes the frontend boundary less generic and increases the chance that backend customization forces frontend conditionals.
- `Primary Lenses:` structure, simplicity
- `Evidence:` [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L78) exposes `RunItemPayload` as raw strings. [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L113) emits `run.item` for `tool_called` and `tool_output`, while [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L176) special-cases only `tool_called` to set `activeAgentName = "Working..."`. The example contract in [streaming.py](/C:/dev/ios-agent-template/backend/app/streaming.py#L62) documents only the `tool_called` path.
- `Related Files:` [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L78), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L95), [streaming.py](/C:/dev/ios-agent-template/backend/app/streaming.py#L45)

## Coverage Gaps

- I did not verify whether the exported shared contract and fixture are regenerated or checked in CI, so the actual drift-prevention mechanism between backend and iOS remains unverified.
- I did not inspect a live network trace from `URLSession.bytes.lines`, so framing behavior was inferred from the code path and the shared fixture, not from a running stream.
- I did not inspect broader backend event suppression outside the immediate stream producer, so additional event types may be filtered before they reach this parser.
