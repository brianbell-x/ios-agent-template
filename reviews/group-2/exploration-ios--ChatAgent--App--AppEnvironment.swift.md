# Exploration Report

## Target

- `Anchor File:` [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift)
- `Related Files Reviewed:`
  - [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift)
  - [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift)
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)
  - [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift)
  - [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift)
  - [Info.plist](/C:/dev/ios-agent-template/ios/ChatAgent/Info.plist)
  - [openapi.json](/C:/dev/ios-agent-template/shared/openapi.json)
- `Intent Context:`
  - Review against a reusable iOS chat app foundation, not a one-off demo.
  - Prioritize maintainability, clear boundaries, and a generic chat-first UX.
  - Backend behavior should remain configurable without frontend rewrites.
  - Avoid feature bloat and unnecessary abstraction.

## Scope Definition

### Anchor Responsibilities

[AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3) is the app bootstrap composition point for the iOS client. It owns:

- selecting runtime configuration from `Info.plist`
- choosing fallback defaults when config is missing or malformed
- constructing the live HTTP client
- constructing the live transcript persistence store
- packaging those dependencies for app startup

### Direct Touch Surface Read

- [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L3) because it is the caller that instantiates `AppEnvironment.live()` and explodes the environment back into `ChatSessionStore` constructor arguments.
- [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L25) because `AppEnvironment` constructs `LiveChatAPIClient(baseURL:)`.
- [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L11) because `AppEnvironment` chooses `TranscriptStore.live()`.
- [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L28) because the environment values are consumed there and shape runtime behavior.
- [Info.plist](/C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21) because it defines the config keys read by `AppEnvironment`.
- [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42) and [openapi.json](/C:/dev/ios-agent-template/shared/openapi.json#L177) because they define whether `agent_id` is optional and what backend config the client contract already exposes.

### Intent Context vs. Code Evidence

- `Intent Context:` reusable foundation, maintainable boundaries, backend configurability without frontend rewrites, avoid unnecessary abstraction.
- `Code Evidence:` runtime config is plist-driven with silent fallbacks, agent selection is sent from the iOS client on every request, transcript persistence is a single local file, and the app composition root passes overlapping backend config in separate fields.

## Engineering Decisions Found

### Decision 1: Runtime bootstrap silently falls back to localhost and default values when plist configuration is missing or malformed

- `Decision:` `AppEnvironment.live()` treats `ChatBackendBaseURL`, `ChatDefaultAgentID`, and `ChatLocalTranscriptLimit` as optional runtime hints and silently substitutes `http://127.0.0.1:8000`, `default`, and `40` when keys are absent or the URL string cannot be parsed.
- `Why Review It:` This makes app startup resilient for local development, but it also makes configuration drift hard to detect because the app can boot against an unintended backend or agent without any explicit signal.
- `Primary Lenses:` operability, simplicity
- `Evidence:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L10) reads each plist key with `??` fallbacks and reparses the URL with a second localhost fallback.
  - [Info.plist](/C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21) checks in those same localhost-oriented defaults.
  - [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L5) instantiates `AppEnvironment.live()` unconditionally at app launch.
- `Related Files:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift)
  - [Info.plist](/C:/dev/ios-agent-template/ios/ChatAgent/Info.plist)
  - [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift)

### Decision 2: The iOS client pins agent selection from app config instead of discovering the backend's current default configuration

- `Decision:` The frontend chooses a single `defaultAgentID` during app bootstrap and sends that `agent_id` on every chat request, even though the shared backend contract already exposes backend-selected defaults and treats `agent_id` as optional.
- `Why Review It:` This is a meaningful product-boundary decision for a reusable chat shell because backend agent reconfiguration can require frontend config changes or rebuilds instead of remaining a backend concern.
- `Primary Lenses:` structure, operability
- `Evidence:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L14) reads `ChatDefaultAgentID` from app configuration.
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L132) always populates `BackendChatRequest.agentID` from `defaultAgentID`.
  - [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift#L42) models `agentID` as optional in the request payload.
  - [openapi.json](/C:/dev/ios-agent-template/shared/openapi.json#L8) exposes `/api/health` with `default_agent_id`, `available_agent_ids`, and `agent_config_version`, but the reviewed iOS files do not consume that configuration surface.
- `Related Files:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift)
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)
  - [ChatModels.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift)
  - [openapi.json](/C:/dev/ios-agent-template/shared/openapi.json)

### Decision 3: Environment composition carries overlapping backend identity in separate fields and pushes that coordination into the root scene and store

- `Decision:` `AppEnvironment` packages a concrete `client` plus separate `backendBaseURL`, `defaultAgentID`, and `localTranscriptLimit`, and `RootScene` reconstructs `ChatSessionStore` by passing all of them individually rather than handing off a narrower backend/session dependency.
- `Why Review It:` This keeps the types simple, but it also mirrors backend semantics across layers and requires callers to keep related values aligned manually, especially when the store uses the raw URL for UI status while the client owns the actual transport behavior.
- `Primary Lenses:` structure, simplicity
- `Evidence:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3) stores both the concrete client and separate backend config values.
  - [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L17) explodes that environment into five constructor arguments for `ChatSessionStore`.
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L16) keeps both `client` and `backendBaseURL`, then uses `backendBaseURL` only for `statusCaption`.
  - [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L25) already embeds the base URL inside `LiveChatAPIClient`.
- `Related Files:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift)
  - [ChatAgentApp.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift)
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)
  - [ChatAPIClient.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift)

### Decision 4: Local transcript persistence is a single global snapshot file, not scoped by backend target or agent configuration

- `Decision:` The live environment always uses one `TranscriptStore` backed by `Application Support/chat_snapshot.json`, and restore logic validates that snapshot against whichever backend is currently configured at launch.
- `Why Review It:` For a reusable foundation, this is an important state-ownership choice because switching backend targets or agent configurations can make persisted state look invalid, forcing resets through normal app startup rather than through an explicit environment boundary.
- `Primary Lenses:` structure, operability
- `Evidence:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L22) always constructs `TranscriptStore.live()`.
  - [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L11) hard-codes one persistence path, `chat_snapshot.json`.
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L64) restores the stored snapshot, verifies it against the current backend, and clears local state when the backend says the conversation no longer exists or status lookup fails.
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195) persists only the capped message history plus `conversationID` and `activeAgentName`, without any backend or agent scoping metadata.
- `Related Files:`
  - [AppEnvironment.swift](/C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift)
  - [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift)
  - [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift)

## Coverage Gaps

- Did not inspect Xcode build settings or per-configuration plist overrides, so this report only verifies the checked-in defaults in [Info.plist](/C:/dev/ios-agent-template/ios/ChatAgent/Info.plist).
- Did not inspect backend server implementation; backend claims in this report come only from the shared API contract in [openapi.json](/C:/dev/ios-agent-template/shared/openapi.json).
