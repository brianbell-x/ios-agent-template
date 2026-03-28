# Decision Review

## Decision

- `Decision:` Keep `ChatSessionStore` as scene-owned `@State` inside a private `RootScene`, and trigger transcript restore from a root-view `.task` via `restoreIfNeeded()` instead of introducing an app-level bootstrap model or coordinator.
- `Scope Reviewed:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L4), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L7), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L3)

## Intent Context

- `Provided Context:` Review against a reusable iOS chat app foundation, prioritize maintainability and clear boundaries, keep the UX generic and chat-first, keep backend behavior configurable without frontend rewrites, and avoid feature bloat or unnecessary abstraction.
- `How It Affected Review:` This raised the bar on session-lifetime ownership. A scene-local store was only acceptable if persistence, restore, and multi-scene behavior still had one clear source of truth without adding frontend-specific coupling.

## Evidence Reviewed

- `Code:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L4), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L7), [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L3), [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L22)
- `Tests/Specs/Diffs:` [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L5)
- `Docs:` [Model data](https://developer.apple.com/documentation/SwiftUI/Model-data), [Bring multiple windows to your SwiftUI app](https://developer.apple.com/videos/play/wwdc2022/10061), [Analyze hangs with Instruments](https://developer.apple.com/videos/play/wwdc2023/10248/?time=2020)

## Lens Check

- `Simplicity:` No material simplicity issue; `@State` owning an observable reference model is SwiftUI-native and avoids an unnecessary bootstrap wrapper.
- `Structure:` Material issue present: scene-local session ownership conflicts with one app-global transcript file and one shared revision gate.
- `Operability:` Material issue present: restore runs in a view task that SwiftUI cancels on disappearance, but cancellation is handled like a terminal restore failure.
- `Scale:` No material scale issue in normal single-scene use; the practical risk is multi-window coordination rather than throughput.

## Findings

### [medium] [structure] Scene-local stores share one global persistence channel

- `Evidence:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L5) creates one `AppEnvironment`, [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L8) uses it for a `WindowGroup`, and [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L15) creates a separate `ChatSessionStore` per `RootScene`; [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L11) always targets one `chat_snapshot.json` file, and [TranscriptStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/TranscriptStore.swift#L45) enforces one actor-global `newestRevision`; Apple's WWDC22 SwiftUI guidance distinguishes `WindowGroup` as a multi-window scene style on iPadOS and macOS, and `Window` as the single-window option for global app state.
- `Problem:` Each scene gets its own in-memory conversation store, but every scene persists through the same transcript actor and the same snapshot file. The per-store `persistenceRevision` counters in [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L196) do not share a namespace, so one scene can suppress or overwrite another scene's persisted state without either scene knowing it.
- `Why It Matters:` Restore behavior becomes nondeterministic as soon as the app has more than one window on supported platforms. That is a real ownership bug, not just a missing feature, and it will surface as hard-to-reproduce transcript loss or stale relaunch state.
- `Better Direction:` Pick one owner for persisted chat state. If the app only wants one app-wide conversation cache, lift the store above `RootScene` so every scene observes the same instance or switch to a single-window scene where appropriate. If multiple scenes are supported, scope persistence and revisioning per scene or per conversation instead of sharing one global snapshot channel.

### [medium] [operability] Restore cancellation is treated as terminal failure

- `Evidence:` [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L33) starts restore in a view `.task`; Apple's SwiftUI concurrency guidance says SwiftUI automatically cancels `.task` work when the corresponding view disappears; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60) sets `hasRestoredSnapshot = true` before any awaited work, [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L80) handles every thrown error by resetting state and scheduling persistence, and [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L26) performs a cancellable network request during restore.
- `Problem:` A normal view-lifecycle cancellation is indistinguishable from a real backend verification failure. Once cancellation happens, the store has already marked restore as done and may clear the saved snapshot, so later appearances do not retry.
- `Why It Matters:` Transient scene churn can leave the app starting from an empty conversation with no clear explanation. That is brittle to support because the failure depends on timing and lifecycle rather than a stable backend or storage condition.
- `Better Direction:` Handle `CancellationError` separately and only mark restore complete after the restore path reaches a deliberate terminal outcome. If restore is supposed to survive transient view disappearance, own the task lifecycle inside `ChatSessionStore` instead of tying it directly to the view modifier.

## Recommended Fix Actions

1. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-2.md | Change: Choose one ownership model for persisted chat state by either sharing a single `ChatSessionStore` across the `WindowGroup` or giving each scene or conversation its own transcript file and revision namespace instead of using scene-local stores with one shared `TranscriptStore`.
2. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--ChatAgentApp.swift--decision-2.md | Change: Update `restoreIfNeeded()` to treat `CancellationError` as non-terminal and to set `hasRestoredSnapshot` only after a completed restore or deliberate reset so a canceled root-view `.task` does not suppress future restore attempts or clear the cached snapshot.

## Sources

- [Model data](https://developer.apple.com/documentation/SwiftUI/Model-data)
- [Bring multiple windows to your SwiftUI app](https://developer.apple.com/videos/play/wwdc2022/10061)
- [Analyze hangs with Instruments](https://developer.apple.com/videos/play/wwdc2023/10248/?time=2020)
