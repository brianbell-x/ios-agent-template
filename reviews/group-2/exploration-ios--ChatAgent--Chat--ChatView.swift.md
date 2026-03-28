# Exploration Report

## Scope

- Anchor File: `ios/ChatAgent/Chat/ChatView.swift`
- Related Files Reviewed: `ios/ChatAgent/Chat/ChatSessionStore.swift`, `ios/ChatAgent/Chat/ChatModels.swift`, `ios/ChatAgent/App/ChatAgentApp.swift`, `ios/ChatAgent/Chat/TranscriptStore.swift`
- Intent Context:
  - Review against a reusable iOS chat app foundation, not a one-off demo.
  - Prioritize maintainability, clear boundaries, and a generic chat-first UX.
  - Backend behavior should remain configurable without frontend rewrites.
  - Avoid feature bloat and unnecessary abstraction.
- Scope Boundary: I read the anchor first, then only the files needed to understand the state, actions, restore flow, and persistence behavior that `ChatView` directly depends on. I did not expand into backend implementation or unrelated iOS modules.

## Anchor Responsibilities

- `ChatView` owns transcript layout, empty-state presentation, inline error presentation, toolbar chrome, composer placement, and auto-scroll behavior.
- The screen binds directly to `ChatSessionStore` for message data, composer state, send/retry/reset actions, status text, and scroll anchoring.
- The same file also owns the private UI building blocks for bubbles, composer, empty state, error card, background, and previews.

## Direct Touch Surface

- App entry creates one `ChatSessionStore`, injects it into `ChatView`, and restores prior state on scene startup in `ios/ChatAgent/App/ChatAgentApp.swift:14-35`.
- `ChatSessionStore` owns backend streaming, retry state, conversation restore, local persistence scheduling, and derived UI state such as `statusCaption` and `scrollAnchorID` in `ios/ChatAgent/Chat/ChatSessionStore.swift:7-223`.
- `ChatModels` defines the message and stream event shapes that `ChatView` renders and reacts to in `ios/ChatAgent/Chat/ChatModels.swift:3-130`.
- `TranscriptStore` persists one conversation snapshot file and is the source of the store's restore/persistence behavior in `ios/ChatAgent/Chat/TranscriptStore.swift:3-55`.

## Engineering Decisions Found

### Decision 1: Full-screen binding to `ChatSessionStore`

- Decision: Bind `ChatView` directly to the full `ChatSessionStore` API instead of passing narrower screen state and actions.
- Why Review It: This sets the main UI boundary for the reusable chat foundation. It simplifies wiring, but it also lets the view depend directly on conversation restore, retry, persistence, and backend-derived status semantics.
- Primary Lenses: `structure`, `simplicity`
- Evidence: `ChatView` reads and invokes store members across the screen in `ios/ChatAgent/Chat/ChatView.swift:5-88`. `ChatSessionStore` combines UI-facing state with networking, restore, retry, and persistence behavior in `ios/ChatAgent/Chat/ChatSessionStore.swift:7-223`. The app root injects the store directly into the view in `ios/ChatAgent/App/ChatAgentApp.swift:14-35`.
- Related Files: `ios/ChatAgent/Chat/ChatView.swift`, `ios/ChatAgent/Chat/ChatSessionStore.swift`, `ios/ChatAgent/App/ChatAgentApp.swift`

### Decision 2: Hardcoded UX copy and sample prompts inside the core chat screen

- Decision: Keep the empty-state suggestions, product explanation copy, toolbar title, and bubble role labels hardcoded inside `ChatView`.
- Why Review It: This keeps the screen compact, but it also fixes product framing and starter behavior inside the reusable frontend surface, which reduces how far backend configuration alone can reshape the experience.
- Primary Lenses: `simplicity`, `structure`
- Evidence: The suggestion list is inline in `ios/ChatAgent/Chat/ChatView.swift:18-25`. The toolbar title is fixed in `ios/ChatAgent/Chat/ChatView.swift:48-53`. The role labels and empty-state copy are fixed in `ios/ChatAgent/Chat/ChatView.swift:103-107` and `ios/ChatAgent/Chat/ChatView.swift:208-230`.
- Related Files: `ios/ChatAgent/Chat/ChatView.swift`

### Decision 3: View-driven transcript scrolling on both message creation and message text deltas

- Decision: Drive transcript auto-scroll from `ChatView` with one change handler keyed to `scrollAnchorID` and another keyed to `messages.last?.text`, both animating to the bottom.
- Why Review It: This is the local mechanism that makes streamed replies feel live, but it also ties responsiveness to per-delta scroll work in the view, which matters for long responses, frequent event streams, and user-driven scrolling.
- Primary Lenses: `operability`, `scale`, `simplicity`
- Evidence: The view scrolls on both `store.scrollAnchorID` and `store.messages.last?.text` in `ios/ChatAgent/Chat/ChatView.swift:77-88`. The store derives `scrollAnchorID` from the last message in `ios/ChatAgent/Chat/ChatSessionStore.swift:46-48` and mutates the last assistant message on every delta in `ios/ChatAgent/Chat/ChatSessionStore.swift:169-173`.
- Related Files: `ios/ChatAgent/Chat/ChatView.swift`, `ios/ChatAgent/Chat/ChatSessionStore.swift`

### Decision 4: Narrow operational surface for status and failure recovery

- Decision: Surface chat runtime state through a single toolbar caption plus one inline error card, while keeping persistence failures in store state without rendering them in `ChatView`.
- Why Review It: This defines what users can actually observe and recover from in the core chat UX. The minimal chrome is consistent with the product direction, but it also makes some failure modes rely on logs or hidden state instead of visible recovery cues.
- Primary Lenses: `operability`, `structure`
- Evidence: `ChatView` renders only `store.statusCaption` and `store.inlineError` in `ios/ChatAgent/Chat/ChatView.swift:36-38` and `ios/ChatAgent/Chat/ChatView.swift:48-53`. `ChatSessionStore` tracks `inlineError` and a separate `persistenceIssue` in `ios/ChatAgent/Chat/ChatSessionStore.swift:11-14`, computes the caption in `ios/ChatAgent/Chat/ChatSessionStore.swift:50-58`, and records persistence failures in `ios/ChatAgent/Chat/ChatSessionStore.swift:195-223`.
- Related Files: `ios/ChatAgent/Chat/ChatView.swift`, `ios/ChatAgent/Chat/ChatSessionStore.swift`, `ios/ChatAgent/Chat/TranscriptStore.swift`

### Decision 5: Disable new-conversation reset while streaming

- Decision: Disable the toolbar's new-conversation control whenever `isStreaming` is true even though `startNewConversation()` cancels the active task and clears state.
- Why Review It: This encodes the interruption policy for the app's main chat surface. It matters operationally because the store already contains a cancellation/reset path, but the primary UI withholds that path during long-running or stuck turns.
- Primary Lenses: `operability`, `structure`
- Evidence: The toolbar button calls `store.startNewConversation` but is disabled when streaming in `ios/ChatAgent/Chat/ChatView.swift:58-63`. The store implementation cancels `sendTask`, resets state, and persists the reset in `ios/ChatAgent/Chat/ChatSessionStore.swift:100-107`.
- Related Files: `ios/ChatAgent/Chat/ChatView.swift`, `ios/ChatAgent/Chat/ChatSessionStore.swift`

## Coverage Gaps

- I did not inspect the backend stream producer, so event ordering and delta frequency were inferred only from the client-side event models and store handling.
- I did not find iOS tests that exercise `ChatView` or `ChatSessionStore`; the visible iOS test target in this repository appears limited to parser coverage.

## Saved Output

- Exploration Output Path: `reviews/group-2/exploration-ios--ChatAgent--Chat--ChatView.swift.md`
