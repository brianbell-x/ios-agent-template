# Decision Review

## Decision

- `Decision:` The iOS app selects `defaultAgentID` from bundle configuration at startup and sends that `agent_id` on every chat request instead of relying on the backend's current default-agent selection.
- `Scope Reviewed:` [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift), [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift), [Info.plist](/C:/dev/ios-agent-template/ios/ChatAgent/Info.plist), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py), [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py), [chat.py](/C:/dev/ios-agent-template/backend/app/schemas/chat.py)

## Intent Context

- `Provided Context:` Review against a reusable iOS chat app foundation, prioritize maintainability and clear boundaries, keep backend behavior configurable without frontend rewrites, and avoid feature bloat or unnecessary abstraction.
- `How It Affected Review:` This context made default-agent ownership a boundary question, not just a convenience choice. A frontend-owned default is only justified if it buys a clear product capability, and this implementation does not show one.

## Evidence Reviewed

- `Code:` [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3), [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L13), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L8), [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L3), [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42), [Info.plist](/C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21), [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L49), [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L38), [chat.py](/C:/dev/ios-agent-template/backend/app/schemas/chat.py#L6)
- `Tests/Specs/Diffs:` [openapi.json](/C:/dev/ios-agent-template/shared/openapi.json#L8), [architecture.md](/C:/dev/ios-agent-template/docs/architecture.md#L13), [README.md](/C:/dev/ios-agent-template/README.md#L12)
- `Docs:` None

## Lens Check

- `Simplicity:` Material issue: `ChatDefaultAgentID` is an extra config surface with no clear payoff in the current chat-only client because the backend already defaults `agent_id`.
- `Structure:` Material issue: default-agent ownership is split across iOS bundle config and backend settings, which weakens the stated backend-owned customization boundary.
- `Operability:` Material issue: backend default changes can silently fail to roll out or degrade into `unknown_agent` errors when the client-pinned id drifts from server config.
- `Scale:` No material issue; this decision does not meaningfully change throughput, concurrency, or growth characteristics.

## Findings

### [medium] [structure] Client duplicates backend default-agent ownership

- `Evidence:` [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L14) reads `ChatDefaultAgentID`, [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L17) passes it into `ChatSessionStore`, and [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L132) always sends `agentID: self.defaultAgentID`. The backend request schema keeps `agent_id` optional in [chat.py](/C:/dev/ios-agent-template/backend/app/schemas/chat.py#L8), the service already falls back to `self._settings.default_agent_id` in [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L58) and [service.py](/C:/dev/ios-agent-template/backend/app/agents/service.py#L76), and `/api/health` exposes `default_agent_id` plus `agent_config_version` in [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L38). The iOS transport surface in [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L3) has no configuration bootstrap call, so the client never reconciles its pinned id with backend state.
- `Problem:` The app carries a second source of truth for the default agent even though the frontend has no agent-switching UX and the backend is already designed to own default selection. That makes `ChatDefaultAgentID` a speculative config surface rather than a required product capability.
- `Why It Matters:` Backend reconfiguration stops being backend-only. Changing the backend default to another valid agent will not affect current clients, while removing or renaming the client-pinned id can turn requests into `unknown_agent` failures handled in [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L76) and [routes_chat.py](/C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L126). That adds coordination burden across app config, backend env, and agent catalog, which is the opposite of the repo's reusable-foundation goal.
- `Better Direction:` Let the backend own the normal default path by omitting `agent_id` on routine chat turns. Keep client-sent `agent_id` only for an explicit override mode, and add bootstrap discovery only if the UI truly needs to surface backend configuration.

## Recommended Fix Actions

1. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--AppEnvironment.swift--decision-2.md | Change: Stop populating `BackendChatRequest.agent_id` in the normal chat flow and let the backend choose `Settings.default_agent_id` when no explicit client override is intended.
2. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--AppEnvironment.swift--decision-2.md | Change: Remove `ChatDefaultAgentID` from `AppEnvironment` and `Info.plist`, or rename it to an explicit fixed-agent override so the frontend no longer carries a second default-agent source of truth.

## Sources

None
