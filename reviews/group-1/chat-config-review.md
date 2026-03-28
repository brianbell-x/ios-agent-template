# Decision Review

## Decision

- `Decision:` Keep the backend public contract chat-shaped while resolving model, tool, handoff, guardrail, session, and MCP choices behind server-side configuration and registries.
- `Scope Reviewed:` [backend/app/schemas/chat.py](C:/dev/ios-agent-template/backend/app/schemas/chat.py#L8), [backend/app/api/routes_chat.py](C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L49), [backend/app/agents/service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L35), [backend/app/agents/catalog.py](C:/dev/ios-agent-template/backend/app/agents/catalog.py#L10), [backend/app/agents/definitions.py](C:/dev/ios-agent-template/backend/app/agents/definitions.py#L9), [backend/app/agents/extensions.py](C:/dev/ios-agent-template/backend/app/agents/extensions.py#L49), [backend/app/agents/builder.py](C:/dev/ios-agent-template/backend/app/agents/builder.py#L21), [backend/config/agents/default.yaml](C:/dev/ios-agent-template/backend/config/agents/default.yaml), [backend/config/agents/planner.yaml](C:/dev/ios-agent-template/backend/config/agents/planner.yaml), [backend/config/agents/researcher.yaml](C:/dev/ios-agent-template/backend/config/agents/researcher.yaml)

## Evidence Reviewed

- `Code:` [backend/app/schemas/chat.py](C:/dev/ios-agent-template/backend/app/schemas/chat.py#L8), [backend/app/api/routes_chat.py](C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L49), [backend/app/agents/service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L47), [backend/app/agents/catalog.py](C:/dev/ios-agent-template/backend/app/agents/catalog.py#L20), [backend/app/agents/definitions.py](C:/dev/ios-agent-template/backend/app/agents/definitions.py#L57), [backend/app/agents/extensions.py](C:/dev/ios-agent-template/backend/app/agents/extensions.py#L128), [backend/app/agents/builder.py](C:/dev/ios-agent-template/backend/app/agents/builder.py#L33)
- `Tests/Specs/Diffs:` [backend/tests/test_agent_catalog.py](C:/dev/ios-agent-template/backend/tests/test_agent_catalog.py#L4), [backend/tests/test_chat_service.py](C:/dev/ios-agent-template/backend/tests/test_chat_service.py#L53), [docs/architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L11), [README.md](C:/dev/ios-agent-template/README.md#L14). Live `uv run pytest` was attempted but blocked in this environment by a local `uv` cache permission error.
- `Docs:` None

## Lens Check

- `Simplicity:` The narrow chat API is a good simplification, but the config/registry path adds avoidable moving parts where validation and session ownership are inconsistent.
- `Structure:` Backend boundaries are mostly clean, but session strategy is coupled to `ChatService` instead of living beside the other agent extension seams.
- `Operability:` Material config mistakes fail late on the request path and are reduced to generic backend errors, which makes incident handling and debugging unnecessarily hard.
- `Scale:` Rebuilding the agent graph and reopening MCP contexts on every turn introduces repeated work that will age poorly once more agents or MCP servers are configured.

## Findings

### [medium] [operability] Config errors surface only on live requests

- `Evidence:` [backend/app/agents/catalog.py](C:/dev/ios-agent-template/backend/app/agents/catalog.py#L20) loads YAML and validates only the schema shape from [backend/app/agents/definitions.py](C:/dev/ios-agent-template/backend/app/agents/definitions.py#L57). Registry resolution and instruction file loading happen later inside [backend/app/agents/builder.py](C:/dev/ios-agent-template/backend/app/agents/builder.py#L53) and [backend/app/agents/extensions.py](C:/dev/ios-agent-template/backend/app/agents/extensions.py#L142). Request handlers then collapse unexpected exceptions into a generic `backend_error` in [backend/app/api/routes_chat.py](C:/dev/ios-agent-template/backend/app/api/routes_chat.py#L77).
- `Problem:` A bad tool id, guardrail id, handoff id, missing instructions file, or invalid model settings is not rejected when the service starts; it breaks only when a matching chat request hits that agent.
- `Why It Matters:` The health endpoint can stay green while a configured agent is unusable, and the first failing request returns an opaque 500 that hides the real configuration mistake.
- `Better Direction:` Validate the fully resolved agent graph at startup or catalog reload time, including instruction file existence, handoff references, registry membership, and `ModelSettings` construction, then fail fast with a precise configuration error.

### [medium] [structure] Session selection is not behind the same extension seam

- `Evidence:` The local specs say session choice stays inside backend configuration and small registries in [docs/architecture.md](C:/dev/ios-agent-template/docs/architecture.md#L23) and [README.md](C:/dev/ios-agent-template/README.md#L20), but [backend/app/agents/service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L47) directly constructs `SQLiteSession` in both `respond()` and `stream()`.
- `Problem:` Session strategy is the one advertised extension point that is still hardcoded in the request-path service instead of being resolved through the same backend composition model as tools, handoffs, guardrails, and MCP wiring.
- `Why It Matters:` Swapping to a different session backend now requires editing transport code and duplicating the change in multiple methods, which weakens the claimed separation of concerns and increases doc drift.
- `Better Direction:` Inject a small session provider or factory from settings or the agent runtime layer so `ChatService` only handles request/response flow and does not choose the concrete session implementation.

### [medium] [scale] Agent and MCP setup is repeated for every turn

- `Evidence:` Every call to [backend/app/agents/service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L51) and [backend/app/agents/service.py](C:/dev/ios-agent-template/backend/app/agents/service.py#L75) opens `agent_factory.lifecycle()`. That lifecycle creates a fresh `AsyncExitStack` and per-call cache in [backend/app/agents/builder.py](C:/dev/ios-agent-template/backend/app/agents/builder.py#L33), recursively rebuilds the full agent graph in [backend/app/agents/builder.py](C:/dev/ios-agent-template/backend/app/agents/builder.py#L43), and enters each MCP server context in [backend/app/agents/builder.py](C:/dev/ios-agent-template/backend/app/agents/builder.py#L99).
- `Problem:` Identical agent definitions, handoff trees, tools, guardrails, and MCP connections are reconstructed on every request even though the conversation-specific state already lives in the session.
- `Why It Matters:` Latency and resource cost grow with each configured handoff or MCP server, and concurrency pressure rises because setup work is repeated instead of amortized across requests.
- `Better Direction:` Compile and cache immutable agent graphs separately from per-conversation session state, and keep MCP server lifecycles at process or config-reload scope rather than request scope.

## Recommended Fix Actions

1. Add startup validation that resolves every configured agent once and rejects missing instruction files, unknown handoffs, unknown registry ids, and invalid model settings before the app serves traffic.
2. Replace direct `SQLiteSession` construction in `ChatService` with an injected session factory so session backend changes do not require editing transport code.
3. Cache built agent graphs by config version and move MCP server setup out of the per-request lifecycle, rebuilding only when configuration changes or the process restarts.

## Sources

None

