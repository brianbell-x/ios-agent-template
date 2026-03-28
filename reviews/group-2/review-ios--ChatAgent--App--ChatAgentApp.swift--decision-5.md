# Decision Review

## Decision

- `Decision:` Mirror backend `sessionHistoryLimit` into local transcript restore and persistence by using one mutable `transcriptLimit` that is seeded from `ChatLocalTranscriptLimit` and then overwritten from backend status and stream payloads before restore and save.
- `Scope Reviewed:` [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L14), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L7), [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L3), [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L36), [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L35), [sessions.py](/C:/dev/ios-agent-template/backend/app/sessions.py#L8), [config.py](/C:/dev/ios-agent-template/backend/app/core/config.py#L13)

## Intent Context

- `Provided Context:` Review against a reusable iOS chat app foundation, prioritize maintainability and clear boundaries, keep the UX generic and chat-first, keep backend behavior configurable without frontend rewrites, and avoid feature bloat or unnecessary abstraction.
- `How It Affected Review:` This raised the bar on ownership boundaries. The question was not just whether one shared limit works, but whether server session policy and client transcript retention remain understandable, configurable, and independently maintainable in a reusable foundation.

## Evidence Reviewed

- `Code:` [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L17), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L39), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L68), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L168), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L183), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L198), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L225), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L80), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L135), [sessions.py](/C:/dev/ios-agent-template/backend/app/sessions.py#L11), [config.py](/C:/dev/ios-agent-template/backend/app/core/config.py#L31)
- `Tests/Specs/Diffs:` [README.md](/C:/dev/ios-agent-template/README.md#L51), [architecture.md](/C:/dev/ios-agent-template/docs/architecture.md#L64), [ChatStreamParserTests.swift](/C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L1)
- `Docs:` None

## Lens Check

- `Simplicity:` Material issue present: the app exposes a local transcript cap and a backend session-history cap, but live behavior silently makes the backend value authoritative after restore or the first streamed response.
- `Structure:` Material issue present: a backend session-memory setting is reused as the client restore and persistence policy, so server prompt-tuning concerns leak into frontend storage behavior.
- `Operability:` Material issue present: backend config changes can silently change how much local history is restored or persisted, and there is no focused iOS test coverage pinning that retention handoff.
- `Scale:` Mixed: sharing one bound avoids unlimited local growth, but overwriting the client cap with a server-controlled value removes the iOS app's independent restore and storage budget.

## Findings

### [medium] [structure] Backend session tuning silently becomes the iOS transcript-retention policy

- `Evidence:` [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L17) reads `ChatLocalTranscriptLimit` as iOS configuration; [README.md](/C:/dev/ios-agent-template/README.md#L53) and [architecture.md](/C:/dev/ios-agent-template/docs/architecture.md#L66) document backend session retrieval and iOS transcript persistence as separate defaults; [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L39) seeds `transcriptLimit` from the local value, but [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L68), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L168), and [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L183) overwrite it from backend `sessionHistoryLimit`; that same mutable field then drives restore and save via [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L198) and [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L225); the backend value comes from configurable server session settings in [config.py](/C:/dev/ios-agent-template/backend/app/core/config.py#L31), [sessions.py](/C:/dev/ios-agent-template/backend/app/sessions.py#L11), and [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L139).
- `Problem:` The code models local transcript retention and backend session history as separate settings, but runtime behavior collapses them through hidden precedence. `ChatLocalTranscriptLimit` is therefore not the local persistence policy its name and docs imply; it is only a bootstrap default until the backend replies.
- `Why It Matters:` This weakens the client-server boundary in a reusable foundation. Backend operators can change prompt-retrieval limits for cost or model-context reasons and unintentionally change client-visible restore depth, local disk usage, and launch workload without touching iOS configuration. That is a maintainability and support cost, not just a stylistic issue.
- `Better Direction:` Keep the concepts separate. Preserve a client-owned local transcript cap, track backend-advertised session history separately, and if the UI must stay within backend memory, derive an explicitly named effective limit such as `min(localTranscriptLimit, backendSessionHistoryLimit)` instead of overwriting the local policy in place.

## Recommended Fix Actions

1. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-5.md | Change: Stop overwriting the local transcript cap with backend `sessionHistoryLimit`; keep a client-owned `localTranscriptLimit`, store the backend-advertised limit separately, and derive an explicitly named effective restore or persistence limit only where the two policies must meet.
2. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-5.md | Change: Add focused iOS tests for restore and persistence when `ChatLocalTranscriptLimit` and backend `sessionHistoryLimit` differ so limit precedence, pruning, and retained-message counts are fixed behavior instead of incidental.
3. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-5.md | Change: Update README and architecture documentation to describe the exact ownership and precedence of local transcript retention versus backend session history so the two-setting model is not misleading.

## Sources

None
