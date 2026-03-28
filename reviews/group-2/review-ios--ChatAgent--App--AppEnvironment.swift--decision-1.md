# Decision Review

## Decision

- `Decision:` `AppEnvironment.live()` treats `ChatBackendBaseURL`, `ChatDefaultAgentID`, and `ChatLocalTranscriptLimit` as optional live configuration and silently substitutes `http://127.0.0.1:8000`, `default`, and `40` when the plist values are missing or malformed.
- `Scope Reviewed:` [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L3), [Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21), [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L4), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L16), [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L47)

## Intent Context

- `Provided Context:` Review against a reusable iOS chat app foundation, prioritize maintainability and clear boundaries, keep the UX generic and chat-first, keep backend behavior configurable without frontend rewrites, and avoid feature bloat or unnecessary abstraction.
- `How It Affected Review:` This made demo-style recovery defaults less acceptable. The live app bootstrap needed to keep environment selection explicit and diagnosable across future targets instead of silently self-configuring to a localhost development shape.

## Evidence Reviewed

- `Code:` [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L10), [Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21), [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L5), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L50), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L60), [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L132), [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L48), [ChatAPIClient.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatAPIClient.swift#L29)
- `Tests/Specs/Diffs:` [README.md](C:/dev/ios-agent-template/README.md#L51), [architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L64), [ChatStreamParserTests.swift](C:/dev/ios-agent-template/ios/Tests/ChatStreamSupportTests/ChatStreamParserTests.swift#L5) as the only nearby iOS test target; no config/bootstrap tests were found
- `Docs:` None

## Lens Check

- `Simplicity:` Material issue present: the hardcoded `??` defaults add a second hidden config source on top of the checked-in plist defaults and buy little beyond masking bad config.
- `Structure:` Material issue present: runtime ownership of backend settings is split across `Info.plist`, `AppEnvironment.swift`, and docs, so the live source of truth is ambiguous.
- `Operability:` Material issue present: missing or malformed bundle config silently routes the app to localhost, `default`, and `40`, then fails later as generic restore or network problems.
- `Scale:` No material scale issue; the cost is supportability and configuration drift rather than throughput.

## Findings

### [medium] [operability] Silent fallback hides real target configuration errors

- `Evidence:` [AppEnvironment.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/AppEnvironment.swift#L10) reads all three plist keys with fallback literals and reparses the URL with another localhost fallback; [Info.plist](C:/dev/ios-agent-template/ios/ChatAgent/Info.plist#L21) already checks in those same development defaults; [ChatAgentApp.swift](C:/dev/ios-agent-template/ios/ChatAgent/App/ChatAgentApp.swift#L5) instantiates the environment unconditionally at launch; [ChatSessionStore.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatSessionStore.swift#L50) derives the status caption from the configured URL and [ChatView.swift](C:/dev/ios-agent-template/ios/ChatAgent/Chat/ChatView.swift#L48) shows it in the navigation chrome; [README.md](C:/dev/ios-agent-template/README.md#L78) instructs developers to replace `ChatBackendBaseURL` for device use, so target-specific configuration changes are an expected maintenance path.
- `Problem:` The fallback layer turns live configuration into optional magic. If a target drops a plist key or stores an invalid URL, the app still boots against `127.0.0.1`, `default`, and `40` instead of surfacing a configuration error. Because the same defaults are already in `Info.plist`, the extra Swift fallbacks mostly create a second source of truth rather than meaningful resilience.
- `Why It Matters:` In a reusable app foundation with multiple targets and environments, that makes misconfiguration harder to detect and debug. The first visible symptom becomes a later connection or restore failure, while the UI can still show a healthy-looking host label derived from the fallback value. That is a real operability risk and a maintenance trap, not just a style preference.
- `Better Direction:` Keep intentional local-development defaults in one checked-in configuration source, but make the live bootstrap validate them explicitly. Missing or malformed runtime values should fail fast with a clear diagnostic or block the chat surface behind a visible configuration error; preview and test conveniences should live behind separate non-production initializers instead of hidden live fallbacks.

## Recommended Fix Actions

1. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--AppEnvironment.swift--decision-1.md | Change: Remove the live `??` and URL reparsing fallbacks from `AppEnvironment.live()` and validate `ChatBackendBaseURL`, `ChatDefaultAgentID`, and `ChatLocalTranscriptLimit` as required bundle configuration with a clear startup diagnostic when any value is missing or malformed.
2. Review Output Path: reviews/group-2/review-ios--ChatAgent--App--AppEnvironment.swift--decision-1.md | Change: Keep local-development defaults in one checked-in configuration source such as `Info.plist` or xcconfig substitution, and move preview or test convenience defaults into a dedicated non-production initializer so runtime targets no longer have two sources of truth.

## Sources

None
