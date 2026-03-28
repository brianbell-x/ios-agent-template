# Decision Review

## Decision

- `Decision:` Build the app's live dependencies in `ChatAgentApp` through `AppEnvironment.live()`, reading `ChatBackendBaseURL`, `ChatDefaultAgentID`, and `ChatLocalTranscriptLimit` from `Info.plist`, then constructing `LiveChatAPIClient` and `TranscriptStore` in the iOS target for `ChatSessionStore`.
- `Scope Reviewed:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L3), [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3), [Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L28), [ChatModels.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42), [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L25), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L11), [service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L57), [config.py](C:/dev/ios-agent-template/backend/app/core/config.py#L13)

## Intent Context

- `Provided Context:` Review against a reusable iOS chat app foundation, prioritize maintainability and clear boundaries, keep the UX generic and chat-first, keep backend behavior configurable without frontend rewrites, and avoid feature bloat or unnecessary abstraction.
- `How It Affected Review:` This raised the bar on client and backend ownership boundaries. The small `AppEnvironment` wrapper itself was judged acceptable, but any client-owned agent-selection or hidden configuration behavior counted as a real issue because it weakens the promised reusable frontend boundary.

## Evidence Reviewed

- `Code:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L3), [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L10), [Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L28), [ChatModels.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42), [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L25), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L11), [service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L57), [config.py](C:/dev/ios-agent-template/backend/app/core/config.py#L13)
- `Tests/Specs/Diffs:` [test_chat_service.py](C:/dev/ios-agent-template/backend/tests/test_chat_service.py#L67), [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L3), [README.md](C:/dev/ios-agent-template/README.md#L13)
- `Docs:` None

## Lens Check

- `Simplicity:` `AppEnvironment` is a small, reasonable composition point, but `ChatDefaultAgentID` adds a second default-selection surface the backend already owns.
- `Structure:` The app root takes responsibility for default agent choice even though the backend contract already supports server-side defaulting, so ownership is split across client bundle config and backend settings.
- `Operability:` Silent fallback from missing or malformed bundle values to `http://127.0.0.1:8000`, `"default"`, and `40` hides misconfiguration and turns setup mistakes into opaque runtime failures.
- `Scale:` No material scale issue is evident; this is startup wiring with no meaningful throughput or growth bottleneck.

## Findings

### [medium] [structure] Client bundle duplicates backend default-agent ownership

- `Evidence:` [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L14) loads `ChatDefaultAgentID`; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L132) sends it on every request; [ChatModels.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42) makes `agent_id` optional; [service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L57) and [service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L75) already resolve a missing `agent_id` to the backend default; [config.py](C:/dev/ios-agent-template/backend/app/core/config.py#L24) keeps that default server-side; [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L22) says the frontend stays generic while backend agent behavior stays server-configured.
- `Problem:` The iOS app carries its own default agent identifier even though the backend already has a native defaulting mechanism. That duplicates semantics across two configuration surfaces and pushes routine agent selection coordination onto the mobile target.
- `Why It Matters:` Changing the backend default agent or shipping different agent catalogs by environment now requires a matching iOS config change and potentially an app release. That weakens the reusable chat-client boundary the repo says it wants.
- `Better Direction:` Treat `agent_id` as an optional client override only. Remove `ChatDefaultAgentID` from the default app wiring and let the backend choose the default agent unless a future UI intentionally exposes agent selection.

### [medium] [operability] Silent localhost fallback masks invalid app configuration

- `Evidence:` [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L10) silently falls back to `http://127.0.0.1:8000`, `"default"`, and `40`, and a malformed `ChatBackendBaseURL` is coerced back to localhost at [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L20); [Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21) stores deployment-specific values; [README.md](C:/dev/ios-agent-template/README.md#L78) says physical-device builds must replace `ChatBackendBaseURL`.
- `Problem:` Missing keys, misspelled keys, or malformed URLs do not produce an explicit startup failure, log, or user-visible configuration error. The app instead attempts to talk to localhost and only fails later as an ordinary network issue.
- `Why It Matters:` Environment mistakes become slow to diagnose, especially across build configurations or device testing where localhost is wrong by default. Operational debugging effort goes up because the failure model points at networking instead of configuration.
- `Better Direction:` Keep a single declared development default if needed, but validate bundle config eagerly and surface configuration failures explicitly, for example by asserting in debug and showing a clear startup error or log in non-debug builds when required keys are absent or malformed.

## Recommended Fix Actions

1. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-1.md | Change: Remove `ChatDefaultAgentID` from `AppEnvironment` and `ChatSessionStore` default wiring, send `agent_id` only when the client is intentionally overriding the backend default, and rely on backend `default_agent_id` for normal chat flows.
2. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-1.md | Change: Replace silent fallback parsing in `AppEnvironment.live()` with explicit configuration validation that logs or surfaces a startup configuration error when `ChatBackendBaseURL` is missing or malformed instead of silently reverting to localhost.

## Sources

None
