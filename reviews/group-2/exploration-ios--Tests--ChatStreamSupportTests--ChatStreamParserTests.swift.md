# Exploration Report

## Scope

- Anchor File: `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift`
- Related Files Reviewed:
  - `ios/ChatAgent/Chat/ChatStreamParser.swift`
  - `ios/ChatAgent/Chat/ChatModels.swift`
  - `ios/ChatAgent/Chat/ChatAPIClient.swift`
  - `ios/Package.swift`
  - `ios/ChatAgent.xcodeproj/project.pbxproj`
  - `shared/chat-stream-fixture.sse`
  - `shared/chat-stream-contract.json`
  - `backend/scripts/export_openapi.py`
  - `docs/architecture.md`
- Intent Context:
  - Review against a reusable iOS chat app foundation, not a one-off demo.
  - Prioritize maintainability, clear boundaries, and a generic chat-first UX.
  - Backend behavior should remain configurable without frontend rewrites.
  - Avoid feature bloat and unnecessary abstraction.

## Anchor Responsibilities

The anchor file is a fixture-driven parser regression test. It reads the shared SSE sample stream from the repository root, feeds each line into `ChatStreamParser`, flushes the parser at EOF, and asserts the exact ordered `ChatStreamEvent` sequence produced by the current stream contract.

Direct touch surface identified from the anchor:

- `ChatStreamParser` owns line-by-line SSE parsing and event dispatch.
- `ChatStreamEvent` and payload models define the decoded contract the test asserts.
- `shared/chat-stream-fixture.sse` is the input corpus the test uses as its contract sample.
- `ios/Package.swift` defines the only test target that currently hosts this parser test.
- `ios/ChatAgent.xcodeproj/project.pbxproj` shows the app target includes the parser and models directly, but no matching Xcode test target is present.
- `backend/scripts/export_openapi.py` and `shared/chat-stream-contract.json` show the shared fixture is exported from backend-side contract definitions rather than hand-authored in iOS.

## Engineering Decisions Found

### Decision 1: Repo-relative fixture lookup instead of package-managed test resources

- Decision: The parser test locates `shared/chat-stream-fixture.sse` by walking up four parent directories from `#filePath` instead of declaring the fixture as a SwiftPM test resource.
- Why Review It: This keeps one shared fixture visible to multiple stacks, but it also makes the test depend on repository layout and runner working assumptions rather than on an explicit package resource boundary.
- Primary Lenses: simplicity, structure, operability
- Evidence:
  - `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift` builds the fixture path with four `deletingLastPathComponent()` calls before appending `shared/chat-stream-fixture.sse`.
  - `ios/Package.swift` defines `ChatStreamSupportTests` without a `resources` declaration, so the fixture is not packaged with the test target.
- Related Files:
  - `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift`
  - `ios/Package.swift`
  - `shared/chat-stream-fixture.sse`

### Decision 2: Use one backend-exported shared SSE fixture as the parser contract anchor

- Decision: The iOS parser test is anchored to a shared fixture and contract document generated from backend streaming definitions, rather than to iOS-local samples or purely synthetic unit inputs.
- Why Review It: This is a strong cross-stack contract choice. It can reduce frontend/backend drift, but it also makes parser correctness and test maintenance depend on backend export discipline and the fidelity of generated fixtures to real runtime behavior.
- Primary Lenses: structure, operability
- Evidence:
  - `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift` reads `shared/chat-stream-fixture.sse` and asserts its decoded event sequence.
  - `backend/scripts/export_openapi.py` writes both `shared/chat-stream-contract.json` and `shared/chat-stream-fixture.sse` from backend streaming definitions.
  - `docs/architecture.md` describes `shared/chat-stream-contract.json` and `shared/chat-stream-fixture.sse` as the documented SSE contract surface because OpenAPI is not sufficient on its own.
- Related Files:
  - `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift`
  - `shared/chat-stream-fixture.sse`
  - `shared/chat-stream-contract.json`
  - `backend/scripts/export_openapi.py`
  - `docs/architecture.md`

### Decision 3: Keep parser and stream models in a separate SwiftPM library for tests while compiling the same files directly into the app target

- Decision: `ChatModels.swift` and `ChatStreamParser.swift` are exposed through a small `ChatStreamSupport` Swift package for testing, while the Xcode app target also compiles those same source files directly instead of consuming the package product.
- Why Review It: This creates a split module topology around the same source files. It keeps parser tests lightweight, but it also introduces two build surfaces and two integration paths for the same implementation, which can complicate ownership and local verification expectations.
- Primary Lenses: structure, simplicity, operability
- Evidence:
  - `ios/Package.swift` defines the `ChatStreamSupport` target from `ChatAgent/Chat/ChatModels.swift` and `ChatAgent/Chat/ChatStreamParser.swift`, plus a `ChatStreamSupportTests` test target.
  - `ios/ChatAgent.xcodeproj/project.pbxproj` includes `ChatModels.swift` and `ChatStreamParser.swift` directly in the `ChatAgent` app target sources and does not define a test target for this surface.
- Related Files:
  - `ios/Package.swift`
  - `ios/ChatAgent.xcodeproj/project.pbxproj`
  - `ios/ChatAgent/Chat/ChatModels.swift`
  - `ios/ChatAgent/Chat/ChatStreamParser.swift`

### Decision 4: Validate the parser primarily through one canonical happy-path stream sequence

- Decision: The test strategy for this surface is centered on one canonical fixture sequence that covers the expected event order and payload decoding for the current contract.
- Why Review It: The approach is simple and readable, but it also means the local review should judge whether this is an intentional coverage boundary for a reusable chat foundation or whether too much parser behavior is left implicit in untested branches and silent-drop behavior.
- Primary Lenses: simplicity, operability
- Evidence:
  - `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift` contains a single test that feeds one shared fixture and asserts only the success-path sequence ending in `.done`.
  - `ios/ChatAgent/Chat/ChatStreamParser.swift` has additional branches for `.failure`, unknown event names, EOF flush behavior, and selective handling of only `event:` and `data:` lines.
  - `ios/ChatAgent/Chat/ChatAPIClient.swift` treats parsed `.failure` events as thrown transport errors, so parser branch behavior directly affects runtime stream handling.
- Related Files:
  - `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift`
  - `ios/ChatAgent/Chat/ChatStreamParser.swift`
  - `ios/ChatAgent/Chat/ChatAPIClient.swift`

### Decision 5: Expose backend-specific session and agent metadata directly in the client stream event schema

- Decision: The parser contract includes backend-centric fields such as `agent_id`, `final_agent_name`, and `session_history_limit` in normal stream events consumed by the iOS client.
- Why Review It: This is a boundary decision between a generic chat client and backend execution details. It may be exactly the intended contract, but it is worth reviewing against the stated goal that backend behavior remain configurable without frontend rewrites.
- Primary Lenses: structure, simplicity
- Evidence:
  - `ios/ChatAgent/Chat/ChatModels.swift` defines `ConversationStartedPayload` and `MessageCompletedPayload` with `agentID`, `finalAgentName`, and `sessionHistoryLimit`.
  - `shared/chat-stream-fixture.sse` includes those fields in the canonical event sequence.
  - `shared/chat-stream-contract.json` documents the same fields as part of the formal SSE contract.
- Related Files:
  - `ios/ChatAgent/Chat/ChatModels.swift`
  - `shared/chat-stream-fixture.sse`
  - `shared/chat-stream-contract.json`
  - `ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift`

## Coverage Gaps

- I did not inspect the full backend stream emission path beyond the exported contract inputs needed to confirm ownership of the shared fixture.
- I did not run the SwiftPM or Xcode tests, so this report covers code structure and touch-surface decisions only.
