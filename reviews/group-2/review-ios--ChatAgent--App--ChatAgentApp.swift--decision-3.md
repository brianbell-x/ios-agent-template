# Decision Review

## Decision

- `Decision:` Verify any saved `conversationID` with the backend before restoring local transcript state, and reset to a new conversation when the backend session is missing or verification fails.
- `Scope Reviewed:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L14), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60), [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L25), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L3), [routes_chat.py](C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L51), [service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L135), [sessions.py](C:/dev/ios-agent-template/backend/app/sessions.py#L8)

## Intent Context

- `Provided Context:` Review against a reusable iOS chat app foundation, prioritize maintainability and clear boundaries, keep the UX generic and chat-first, keep backend behavior configurable without frontend rewrites, and avoid feature bloat or unnecessary abstraction.
- `How It Affected Review:` This made backend-owned conversation continuity the right baseline, so the existence check itself was judged against whether it preserved that boundary with minimal client logic. The review therefore focused on whether the failure policy stayed maintainable and operationally safe for a generic chat client.

## Evidence Reviewed

- `Code:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L29), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60), [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L29), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L21), [routes_chat.py](C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L51), [service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L75), [sessions.py](C:/dev/ios-agent-template/backend/app/sessions.py#L18)
- `Tests/Specs/Diffs:` [test_chat_service.py](C:/dev/ios-agent-template/backend/tests/test_chat_service.py#L111), [README.md](C:/dev/ios-agent-template/README.md#L84), [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L53)
- `Docs:` None

## Lens Check

- `Simplicity:` No material simplicity issue in adding one narrow status check; it is a small, justified guard against client and backend session divergence.
- `Structure:` No material structure issue; the frontend asks a minimal backend-owned question and does not duplicate session semantics beyond restore behavior.
- `Operability:` Material issue present: the client treats confirmed session absence and transient verification failures as the same destructive outcome.
- `Scale:` No material scale issue; one bounded lookup per restore is modest and does not create a meaningful throughput or growth trap.

## Findings

### [medium] [operability] Transient verification errors erase recoverable local chat state

- `Evidence:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L65) loads the cached snapshot, then [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L67) blocks reuse on `conversationStatus`; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L69) resets only when the backend explicitly reports `exists == false`, but [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L80) also resets on every thrown error; [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L31) throws on transport failures and [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L35) throws on any non-2xx response; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195) persists that reset and [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L51) clears the saved snapshot when the reset produces `nil`.
- `Problem:` The decision is implemented with a generic catch-all fallback that collapses three different states into one path: confirmed missing backend session, transient backend or network failure, and malformed or unexpected status responses. Only the first state proves the cached transcript is stale, but all three currently delete the local recovery point and force a new conversation.
- `Why It Matters:` A backend restart, tunnel drop, offline launch, or temporary 5xx now looks like permanent session loss to the app. That makes startup brittle, destroys user-visible continuity that could have been recovered later, and makes incident diagnosis harder because the destructive fallback hides whether the backend session was actually gone.
- `Better Direction:` Keep the backend existence check, but make it authoritative only when it succeeds and returns `exists == false`. On transport or server-side verification errors, preserve and restore the cached transcript, surface a degraded or unverified state, and retry verification later instead of clearing the snapshot immediately.

## Recommended Fix Actions

1. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-3.md | Change: Update `restoreIfNeeded()` so it clears `conversationID` and persisted transcript state only when `conversationStatus` returns `exists == false`; on thrown verification errors, restore the cached transcript, surface it as unverified or offline, and defer reset until the backend explicitly confirms the session is missing.
2. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-3.md | Change: Add focused restore-path tests covering `exists == true`, `exists == false`, and thrown `conversationStatus` errors so startup restore behavior cannot silently regress back to destructive fallback on transient failures.

## Sources

None
