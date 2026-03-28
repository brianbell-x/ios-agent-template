# Exploration Report

## Scope Definition

- `Anchor File:` [ios/Package.swift](/C:/dev/ios-agent-template/ios/Package.swift)
- `Related Files Reviewed:`
  - [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift)
  - [ios/ChatAgent/Chat/ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift)
  - [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift)
  - [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)
  - [ios/ChatAgent/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift)
  - [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift)
  - [ios/ChatAgent.xcodeproj/project.pbxproj](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj)
  - [shared/chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse)
- `Intent Context:`
  - Build against a reusable iOS chat app foundation, not a one-off demo.
  - Prioritize maintainability, clear boundaries, and a generic chat-first UX.
  - Backend behavior should remain configurable without frontend rewrites.
  - Avoid feature bloat and unnecessary abstraction.

## Anchor Responsibilities

- [ios/Package.swift#L5](/C:/dev/ios-agent-template/ios/Package.swift#L5) defines a Swift package named `ChatStreamSupport`.
- [ios/Package.swift#L7](/C:/dev/ios-agent-template/ios/Package.swift#L7) declares `iOS 17` and `macOS 14` platform support.
- [ios/Package.swift#L11](/C:/dev/ios-agent-template/ios/Package.swift#L11) publishes a single library product.
- [ios/Package.swift#L15](/C:/dev/ios-agent-template/ios/Package.swift#L15) points the target at `ChatAgent/Chat` and narrows it to `ChatModels.swift` and `ChatStreamParser.swift`.
- [ios/Package.swift#L23](/C:/dev/ios-agent-template/ios/Package.swift#L23) declares a separate test target under `Tests/ChatStreamSupportTests`.

## Code Evidence Notes

- The same `ChatModels.swift` and `ChatStreamParser.swift` files selected by the package are still compiled directly into the app target in [ios/ChatAgent.xcodeproj/project.pbxproj#L12](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj#L12), [ios/ChatAgent.xcodeproj/project.pbxproj#L18](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj#L18), [ios/ChatAgent.xcodeproj/project.pbxproj#L173](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj#L173), and [ios/ChatAgent.xcodeproj/project.pbxproj#L175](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj#L175).
- [ios/ChatAgent/Chat/ChatModels.swift#L14](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L14) through [ios/ChatAgent/Chat/ChatModels.swift#L123](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L123) mixes chat transcript state, persistence snapshot data, outbound request DTOs, streamed payload DTOs, and the event enum used by the parser and store.
- [ios/ChatAgent/Chat/ChatAPIClient.swift#L41](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L41) constructs `ChatStreamParser` and turns `.failure` stream events into thrown errors.
- [ios/ChatAgent/Chat/ChatSessionStore.swift#L164](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164) applies parsed events directly to UI-facing chat state and also special-cases `run.item` payload names.
- [ios/ChatAgent/Chat/TranscriptStore.swift#L21](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L21) persists `ConversationSnapshot`, confirming the package-selected models are also the app persistence contract.
- [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L3](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L3) uses `@testable import ChatStreamSupport`.
- [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L7](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L7) builds a fixture path by traversing four parent directories to [shared/chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse).

## Engineering Decisions To Review Later

### Decision 1: Package boundary is carved out of app-owned source files

- `Decision:` Define `ChatStreamSupport` by pointing the package target at `ChatAgent/Chat` and compiling `ChatModels.swift` and `ChatStreamParser.swift` both as package sources and as app target sources.
- `Why Review It:` This is the core modularity choice in the anchor file. It creates a reusable-looking boundary without moving ownership out of the app tree, so later changes to chat state or transport contracts may require coordination across two build shapes of the same files.
- `Primary Lenses:` structure, simplicity
- `Evidence:` [ios/Package.swift#L15](/C:/dev/ios-agent-template/ios/Package.swift#L15) selects `ChatAgent/Chat` with only two sources. Those same files remain in the app target at [ios/ChatAgent.xcodeproj/project.pbxproj#L173](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj#L173) and [ios/ChatAgent.xcodeproj/project.pbxproj#L175](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj#L175). App code still consumes the packaged types directly in [ios/ChatAgent/Chat/ChatAPIClient.swift#L41](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L41) and [ios/ChatAgent/Chat/ChatSessionStore.swift#L164](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164).
- `Related Files:` [ios/Package.swift](/C:/dev/ios-agent-template/ios/Package.swift), [ios/ChatAgent.xcodeproj/project.pbxproj](/C:/dev/ios-agent-template/ios/ChatAgent.xcodeproj/project.pbxproj), [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ios/ChatAgent/Chat/ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift), [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)

### Decision 2: One shared models file carries UI state, persistence state, and transport contracts together

- `Decision:` Keep `ChatMessage`, `ConversationSnapshot`, `BackendChatRequest`, streamed payload DTOs, and `ChatStreamEvent` in one package-selected `ChatModels.swift` file that is shared across the parser, API client, session store, and transcript persistence.
- `Why Review It:` This decision defines the local ownership model for chat data. It may keep the surface small, but it also means persistence rules, frontend transcript state, and backend wire contracts evolve together inside one unit, which is important for maintainability and boundary clarity in a reusable foundation.
- `Primary Lenses:` structure, simplicity
- `Evidence:` [ios/ChatAgent/Chat/ChatModels.swift#L14](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L14), [ios/ChatAgent/Chat/ChatModels.swift#L36](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L36), [ios/ChatAgent/Chat/ChatModels.swift#L42](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42), and [ios/ChatAgent/Chat/ChatModels.swift#L123](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L123) show the mixed concerns in the same file. The persistence layer depends on `ConversationSnapshot` in [ios/ChatAgent/Chat/TranscriptStore.swift#L21](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L21), the network client depends on `BackendChatRequest` and `ConversationStatusPayload` in [ios/ChatAgent/Chat/ChatAPIClient.swift#L29](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L29) and [ios/ChatAgent/Chat/ChatAPIClient.swift#L41](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L41), and the app state store depends on `ChatMessage` and `ChatStreamEvent` in [ios/ChatAgent/Chat/ChatSessionStore.swift#L8](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L8) and [ios/ChatAgent/Chat/ChatSessionStore.swift#L164](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164).
- `Related Files:` [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift)

### Decision 3: The package product currently behaves more like a test seam than a reusable public module

- `Decision:` Publish `ChatStreamSupport` as a library product even though the selected parser and model types are internal and the only observed package consumer in scope is a test target using `@testable import`.
- `Why Review It:` This matters to the reusable-foundation goal because the package boundary may be serving local testability rather than an actual externally consumable module contract. That distinction affects whether the extra manifest and module shape are paying for themselves.
- `Primary Lenses:` simplicity, structure
- `Evidence:` The library product is declared at [ios/Package.swift#L11](/C:/dev/ios-agent-template/ios/Package.swift#L11), but the packaged declarations in [ios/ChatAgent/Chat/ChatModels.swift#L3](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L3) and [ios/ChatAgent/Chat/ChatStreamParser.swift#L3](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L3) are not marked `public`. The package test reaches them through `@testable import` in [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L3](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L3). No additional in-scope code imports `ChatStreamSupport`.
- `Related Files:` [ios/Package.swift](/C:/dev/ios-agent-template/ios/Package.swift), [ios/ChatAgent/Chat/ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [ios/ChatAgent/Chat/ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift), [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift)

### Decision 4: Backend streaming semantics are encoded through handwritten SSE event names and local special cases

- `Decision:` Represent the streamed backend contract with hardcoded SSE event names in `ChatStreamParser` and local UI-facing handling logic in `ChatSessionStore`, including the `run.item` plus `tool_called` behavior.
- `Why Review It:` This is the main extensibility seam between configurable backend agents and the generic chat UI. The choice affects how easy it will be to evolve the stream contract, debug mismatches, and keep the frontend decoupled from backend-specific event vocabulary.
- `Primary Lenses:` operability, structure
- `Evidence:` [ios/ChatAgent/Chat/ChatStreamParser.swift#L39](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift#L39) switches on string event names such as `conversation.started`, `run.item`, and `message.completed`. [ios/ChatAgent/Chat/ChatAPIClient.swift#L59](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L59) feeds those parser results directly into the stream. [ios/ChatAgent/Chat/ChatSessionStore.swift#L164](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164) mutates chat state from those events and maps `payload.name == "tool_called"` to the UI label `"Working..."` at [ios/ChatAgent/Chat/ChatSessionStore.swift#L176](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L176). Parser coverage in scope is one fixture-driven test at [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L6](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L6).
- `Related Files:` [ios/ChatAgent/Chat/ChatStreamParser.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatStreamParser.swift), [ios/ChatAgent/Chat/ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ios/ChatAgent/Chat/ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift)

### Decision 5: Package tests rely on a repo-relative shared fixture outside the package test root

- `Decision:` Validate the package parser against a shared fixture file located outside the package test target and discovered by walking up four directories from the test file path.
- `Why Review It:` This is a local operability choice around test portability and maintenance. It couples the package tests to the current repository layout rather than to package-contained resources, which may matter as the iOS project structure or test runners change.
- `Primary Lenses:` operability, simplicity
- `Evidence:` The test target is declared at [ios/Package.swift#L23](/C:/dev/ios-agent-template/ios/Package.swift#L23). The test builds the fixture location through repeated `deletingLastPathComponent()` calls in [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L7](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L7) and then appends `shared/chat-stream-fixture.sse`, which exists at [shared/chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse).
- `Related Files:` [ios/Package.swift](/C:/dev/ios-agent-template/ios/Package.swift), [ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift), [shared/chat-stream-fixture.sse](/C:/dev/ios-agent-template/shared/chat-stream-fixture.sse)

## Coverage Gaps

- `swift` was not available in this Windows session, so I did not verify package build or test execution from [ios/Package.swift](/C:/dev/ios-agent-template/ios/Package.swift).
- I did not inspect the backend producer of the SSE contract because it sits outside the direct touch surface of the anchor manifest; later review may need that if it evaluates stream-contract stability end to end.
- I did not inspect CI or external package-consumer configuration, so package adoption beyond the local files above remains unverified.
