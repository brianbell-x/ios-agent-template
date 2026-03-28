# Decision Review

## Decision

- `Decision:` Implement the iOS template as a single-screen SwiftUI chat client backed by one root observable store, and maintain it as a hand-authored Xcode project instead of a generated project or build setup.
- `Scope Reviewed:` [ChatAgentTemplateApp.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/App/ChatAgentTemplateApp.swift), [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatView.swift), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift), [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/TranscriptStore.swift), [project.pbxproj](/C:/dev/ios-agent-template/ios/ChatAgentTemplate.xcodeproj/project.pbxproj), [README.md](/C:/dev/ios-agent-template/README.md), [architecture.md](/C:/dev/ios-agent-template/docs/architecture.md), [design-brief.md](/C:/dev/ios-agent-template/docs/design-brief.md)

## Evidence Reviewed

- `Code:` [ChatAgentTemplateApp.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/App/ChatAgentTemplateApp.swift), [ChatView.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatView.swift), [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift), [TranscriptStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/TranscriptStore.swift), [project.pbxproj](/C:/dev/ios-agent-template/ios/ChatAgentTemplate.xcodeproj/project.pbxproj)
- `Tests/Specs/Diffs:` [README.md](/C:/dev/ios-agent-template/README.md), [architecture.md](/C:/dev/ios-agent-template/docs/architecture.md), [design-brief.md](/C:/dev/ios-agent-template/docs/design-brief.md)
- `Docs:` None

## Lens Check

- `Simplicity:` The single-screen UI is appropriately narrow, but the root store now manually coordinates streaming, retry, restore, and persistence, which adds lifecycle glue beyond pure view state.
- `Structure:` The view boundary is mostly clean, yet `ChatSessionStore` owns both presentation state and persistence orchestration, so one type becomes the coordination point for several concerns.
- `Operability:` There is meaningful operational risk in the fire-and-forget snapshot persistence and in the hand-authored Xcode project having no machine-checked verification path.
- `Scale:` No material scale issue is evident for the current one-screen template; the client stays small and does not introduce an obvious throughput bottleneck.

## Findings

### [medium] [operability] Snapshot persistence is unordered and silent on failure

- `Evidence:` [`startNewConversation()` clears state and immediately schedules persistence](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift#L79), [`stream(...)` schedules more snapshot writes during send lifecycle](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift#L96), and [`persistSnapshot()` launches an untracked `Task` that swallows all errors](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift#L174).
- `Problem:` The root store writes conversation snapshots through detached best-effort tasks instead of one ordered persistence path. Save and clear requests can be issued faster than they are durably applied, and write failures are intentionally hidden.
- `Why It Matters:` Local transcript restore can become nondeterministic: a stale snapshot can survive a clear or later state transition, and any persistence bug becomes difficult to diagnose because the failure signal is discarded.
- `Better Direction:` Keep the single root store if desired, but route persistence through one serialized async path owned by the store or `TranscriptStore`, cancel or supersede stale writes, and surface failures to logs or a lightweight debug signal.

### [medium] [operability] The hand-authored Xcode project has no checked source of truth

- `Evidence:` [`project.pbxproj` manually enumerates every file membership and build setting](/C:/dev/ios-agent-template/ios/ChatAgentTemplate.xcodeproj/project.pbxproj#L10), [`the target and source phases are maintained directly in the pbxproj`](/C:/dev/ios-agent-template/ios/ChatAgentTemplate.xcodeproj/project.pbxproj#L103), [`the template setup is "open the xcodeproj and run it"`](/C:/dev/ios-agent-template/README.md#L64), and [`the repository explicitly states the iOS project was not compiled in this environment`](/C:/dev/ios-agent-template/README.md#L110).
- `Problem:` The project file is the only source of truth for file inclusion and build settings, but there is no generator, spec, or automated macOS build verification to catch drift.
- `Why It Matters:` As soon as another engineer extends the template, they have to keep filesystem changes and pbxproj edits synchronized by hand. Breakage will surface late, only on a Mac with Xcode, which is a poor operational posture for a starter template meant to be picked up quickly.
- `Better Direction:` Either adopt a minimal project spec or generator as the canonical definition, or keep the hand-authored project but add a committed macOS `xcodebuild` smoke check so project drift is detected before handoff.

## Recommended Fix Actions

1. Replace detached snapshot writes in [ChatSessionStore.swift](/C:/dev/ios-agent-template/ios/ChatAgentTemplate/Chat/ChatSessionStore.swift) with one ordered persistence mechanism that supersedes stale writes and records failures.
2. Add a machine-checked iOS verification path for the hand-authored project, preferably a macOS `xcodebuild` smoke build in CI; if that is not acceptable, move the project definition into a minimal generator or spec.

## Sources

None
