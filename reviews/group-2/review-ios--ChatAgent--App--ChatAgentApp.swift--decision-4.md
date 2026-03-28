# Decision Review

## Decision

- `Decision:` Use `ChatSessionStore` as the single observable boundary for chat transcript state while also owning request construction, stream event interpretation, retry handling, restore validation, transcript persistence, backend-driven limits, and UI-facing status and error copy, with `ChatView` bound directly to that store.
- `Scope Reviewed:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L7), [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L4), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L3), [ChatModels.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L1), [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L14), [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L3), [chat-stream-contract.json](C:/dev/ios-agent-template/shared/chat-stream-contract.json#L1)

## Intent Context

- `Provided Context:` Review against a reusable iOS chat app foundation, prioritize maintainability and clear boundaries, keep the UX generic and chat-first, keep backend behavior configurable without frontend rewrites, and avoid feature bloat or unnecessary abstraction.
- `How It Affected Review:` This raised the bar for boundary discipline. The decision was judged less on whether one store can work today and more on whether the chosen ownership boundary keeps backend policy changes and operational concerns from leaking into the long-lived chat screen surface.

## Evidence Reviewed

- `Code:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L16), [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L16), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L21), [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L17)
- `Tests/Specs/Diffs:` [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L5), [chat-stream-contract.json](C:/dev/ios-agent-template/shared/chat-stream-contract.json#L53), [ChatStreamParserTests.swift](C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L5)
- `Docs:` None

## Lens Check

- `Simplicity:` One store for one chat screen is a reasonable starting point, but this implementation already packs transport, persistence, restore policy, and presentation mapping into the same type.
- `Structure:` Material issue present: `ChatSessionStore` is a mixed-responsibility boundary, and `ChatView` binds directly to that full surface instead of a narrower screen contract.
- `Operability:` Material issue present: core restore and send failures are mostly reduced to inline user copy, with structured logging only on persistence failure.
- `Scale:` No material scale issue; the store is single-conversation and transcript growth is bounded by `transcriptLimit`.

## Findings

### [medium] [structure] The chat screen store has become the change hotspot for unrelated concerns

- `Evidence:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L16) keeps backend client, persistence, URL, retry, revision, and transcript-limit state alongside screen fields; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L50) derives toolbar copy from backend infrastructure data; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60) owns restore validation and destructive reset policy; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L115) builds outbound requests and drives stream handling; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195) schedules persistence and revision control; [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L4) binds the screen directly to that full type; [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L5) says `ios/` should stay a thin chat client while backend behavior stays server-owned.
- `Problem:` The current boundary is not just a screen model. It also carries backend contract policy, persistence policy, retry semantics, and presentation copy in one mutable object, so the primary UI type becomes the place where unrelated changes accumulate.
- `Why It Matters:` For a reusable chat foundation, this makes backend evolution and local persistence changes more likely to force edits in the same class that the view is directly coupled to. That raises maintenance cost, encourages more state accretion into the same store, and makes it harder to keep the frontend generic when backend behavior changes.
- `Better Direction:` Keep a single screen-facing store if desired, but move restore, request/stream orchestration, and persistence coordination behind a dedicated collaborator so `ChatView` depends on a narrower chat-screen state and action surface.

### [medium] [operability] The main chat failure paths lose diagnostic context inside UI-facing state

- `Evidence:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L80) catches restore failures and converts them straight into inline copy plus a reset; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L149) catches stream failures and stores only `error.localizedDescription`; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L217) is the only place that emits a log, and it covers persistence only; [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L36) renders only `inlineError`; [ChatStreamParserTests.swift](C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L5) covers parser correctness, but I found no iOS tests exercising restore, send, retry, or persistence transitions in this store.
- `Problem:` Because the same store owns operational workflows and user-facing copy, most failures are flattened into a string for the transcript UI. The raw failure category, recovery path, and transition timing are not preserved anywhere except for persistence writes.
- `Why It Matters:` When startup restore clears a session unexpectedly or streaming fails in production, there is very little to inspect beyond what the user saw. That makes debugging and incident handling harder on the app's core path, which is a material support risk for a production-ready foundation.
- `Better Direction:` Preserve typed failure state and add structured logs for restore, stream, retry, and reset transitions, then map that state to user-facing captions and error text separately.

## Recommended Fix Actions

1. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-4.md | Change: Keep `ChatSessionStore` as the screen owner if desired, but extract restore, request or stream orchestration, and transcript persistence into a dedicated collaborator so `ChatView` binds to a narrower chat-screen state and action surface instead of the store's full mixed-responsibility API.
2. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-4.md | Change: Add typed restore and send failure states plus structured logging for restore, retry, stream, and reset transitions, and generate `statusCaption` and inline error copy from that typed state rather than storing only user-facing strings.
3. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-4.md | Change: Add focused iOS tests for restore, send, retry, and persistence state transitions around the extracted coordinator or narrowed store surface so this central chat boundary cannot regress silently.

## Sources

None
