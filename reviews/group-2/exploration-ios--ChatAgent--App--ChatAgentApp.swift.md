# Exploration Report

## Scope Definition

- `Anchor File:` [ios/ChatAgent/App/ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift)
- `Related Files Reviewed:`
  [ios/ChatAgent/App/AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift),
  [ios/ChatAgent/Chat/ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift),
  [ios/ChatAgent/Chat/ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift),
  [ios/ChatAgent/Chat/ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift),
  [ios/ChatAgent/Chat/TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift),
  [ios/ChatAgent/Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist)
- `Intent Context:`
  Review against a reusable iOS chat app foundation, not a one-off demo.
  Prioritize maintainability, clear boundaries, and a generic chat-first UX.
  Backend behavior should remain configurable without frontend rewrites.
  Avoid feature bloat and unnecessary abstraction.
- `Scope Boundary:` I inspected only the app bootstrap file and the concrete SwiftUI, client, and persistence types it directly constructs or calls. I did not broaden into backend implementation or repository-wide architecture.

## Anchor Responsibilities

- [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L4) creates one live environment at app startup and passes it into the root scene.
- [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L15) gives the root scene ownership of a `ChatSessionStore` built from that environment.
- [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L33) triggers one asynchronous restore pass when the root view appears.

## Touched Surface Notes

- [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3) resolves runtime configuration from `Info.plist`, creates the concrete HTTP client, and creates the local transcript store.
- [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L7) owns transcript state, backend streaming, restore logic, retry behavior, persistence scheduling, and user-facing status strings.
- [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L4) binds directly to the store and renders transcript, composer, inline recovery, and chat-specific chrome.
- [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L3) persists a single conversation snapshot in application support.
- [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L25) hard-codes the current REST and SSE endpoints around the configured base URL.

## Engineering Decisions That Merit Review

### Decision 1: Bootstrap the live app with one concrete environment assembled inside the iOS target

- `Decision:` Build the app's live dependencies in `ChatAgentApp` through `AppEnvironment.live()`, sourcing base URL, default agent, and transcript limit from `Info.plist`, and constructing `LiveChatAPIClient` plus `TranscriptStore` directly inside the app target.
- `Why Review It:` This defines the main extension seam for a reusable app foundation. It sets how much backend customization can happen through configuration versus code changes, and it fixes the ownership boundary between app bootstrap and feature code.
- `Primary Lenses:` `simplicity`, `structure`, `operability`
- `Evidence:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L4) stores a single `AppEnvironment.live()` instance on the app type. [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L10) reads three `Info.plist` values and falls back to localhost, `"default"`, and `40`. [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L22) constructs `LiveChatAPIClient` and `TranscriptStore.live()` directly. [Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21) carries those defaults in the app bundle.
- `Related Files:` [ios/ChatAgent/App/ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift), [ios/ChatAgent/App/AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift), [ios/ChatAgent/Chat/ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ios/ChatAgent/Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist)

### Decision 2: Bind conversation lifecycle to a root-scene-owned `ChatSessionStore` restored from a view task

- `Decision:` Keep `ChatSessionStore` as `@State` inside a private `RootScene` and rely on a `.task`-triggered `restoreIfNeeded()` guard for session restoration instead of a separate bootstrap coordinator or app model.
- `Why Review It:` This choice defines when restore runs, how conversation state maps to scene lifecycle, and whether multiple scene instances coordinate or diverge. It is the main ownership decision around chat session lifetime in the frontend.
- `Primary Lenses:` `structure`, `operability`, `scale`
- `Evidence:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L15) stores the session store in `@State` on `RootScene`. [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L33) restores inside `.task`. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L24) uses `hasRestoredSnapshot` as the one-time guard. [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L11) persists a single snapshot file shared by whichever scene instance writes last.
- `Related Files:` [ios/ChatAgent/App/ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift), [ios/ChatAgent/Chat/ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift)

### Decision 3: Treat backend session verification as the gate for restoring local transcript state

- `Decision:` On launch restore, verify any saved `conversationID` against the backend before restoring the local transcript, and reset to a new conversation with an inline message when the session is missing or cannot be verified.
- `Why Review It:` This determines the product's recovery semantics when backend state and local state drift apart. It affects debuggability, offline behavior, user-visible continuity, and how much failure detail survives startup.
- `Primary Lenses:` `operability`, `structure`
- `Evidence:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60) loads the saved snapshot and only restores messages after an optional `conversationStatus` check. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L69) resets the conversation if the backend says the session no longer exists. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L80) also resets on any thrown error with a generic inline message. [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L29) shows that verification is a live network call to `/api/conversations/{id}`.
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift)

### Decision 4: Centralize backend policy, transcript retention, retry state, and UI-facing copy inside `ChatSessionStore`

- `Decision:` Use `ChatSessionStore` as the single coordinator for backend request construction, stream event handling, backend-driven transcript limits, local persistence scheduling, retry state, status caption text, and user-facing inline error strings, while `ChatView` binds directly to those properties and actions.
- `Why Review It:` This is the main local abstraction decision in the chat flow. It keeps the view thin, but it also merges transport policy, persistence policy, and presentation semantics into one observable type that the root scene constructs directly.
- `Primary Lenses:` `simplicity`, `structure`, `operability`
- `Evidence:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L8) holds UI state and captions. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L115) builds the backend request with `defaultAgentID` and `conversationID`. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L164) translates stream events into state mutations. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L195) caps and persists local snapshots. [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L25) binds view actions directly to store methods, and [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L52) renders store-provided status text in the navigation chrome.
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift)

### Decision 5: Mirror the backend session history limit into local persistence by truncating the saved transcript

- `Decision:` Apply the backend-provided `sessionHistoryLimit` to the on-device transcript by truncating restored, displayed, and persisted messages to `transcriptLimit`.
- `Why Review It:` This couples frontend history retention to backend session policy. For a reusable chat foundation, that choice affects UX continuity, storage growth, and whether the local transcript is treated as a cache of server context or as user-facing history.
- `Primary Lenses:` `structure`, `scale`, `operability`
- `Evidence:` [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L68) updates `transcriptLimit` from the conversation status response during restore. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L168) and [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L183) refresh it from stream events. [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L198) persists only `cappedMessages(messages)`. [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L45) writes whatever capped snapshot the store hands it.
- `Related Files:` [ios/ChatAgent/Chat/ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift), [ios/ChatAgent/Chat/TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift), [ios/ChatAgent/Chat/ChatModels.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatModels.swift)

## Coverage Gaps

- I did not inspect backend route handlers or agent configuration because the anchor file only touches the client contract, not backend implementation.
- I did not run the iOS app or verify multi-scene behavior at runtime.
- I found no direct tests covering `ChatAgentApp`, `AppEnvironment`, or `ChatSessionStore` restore and lifecycle behavior in the inspected iOS test targets.
