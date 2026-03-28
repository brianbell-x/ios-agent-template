# Architecture

## Boundaries

- `ios/` is a thin SwiftUI chat client.
- `backend/` owns all OpenAI Agents SDK behavior.
- `shared/` holds exported contract artifacts, including `openapi.json` and the SSE stream contract files.

## Stable API Contract

The public backend API is intentionally narrow:

- `POST /api/chat`
- `POST /api/chat/stream`
- `GET /api/health`
- `GET /api/conversations/{conversation_id}`

The request contract stays chat-shaped:

- `message`
- optional `conversation_id`
- optional `agent_id`

This keeps the iOS app decoupled from SDK churn. Model choice, tools, handoffs, guardrails, sessions, and MCP wiring stay inside backend configuration and Python code.

The stream surface is documented separately in `shared/chat-stream-contract.json` and `shared/chat-stream-fixture.sse`, because OpenAPI does not model the SSE contract well on its own.

## Agent Customization Model

Agent definitions live in `backend/config/agents/*.yaml`.

Each definition can declare:

- `model`
- `instructions` or `instructions_file`
- `tools`
- `handoffs`
- `input_guardrails`
- `output_guardrails`
- `hosted_mcp_tools`
- `mcp_servers`
- `model_settings`

The backend resolves those definitions through small registries in `backend/app/agents/`.

Startup behavior:

- reload YAML definitions
- validate instructions files, handoff references, registry ids, and model settings
- build the full agent graph once
- keep MCP server contexts and built agents alive for reuse across requests

## Session Strategy

The backend uses `SQLiteSession` from the Agents SDK and keys each server-side conversation by `conversation_id`.

Why this default:

- it preserves multi-turn context without forcing the client to resend transcript history
- it is easy to understand locally
- it can be swapped later for another `Session` implementation or an OpenAI-managed continuation strategy
- it is now centralized behind a dedicated session factory instead of being hardcoded in the request handlers

Default retention:

- backend session retrieval limit: `40`
- iOS persisted transcript limit: `40`

## Streaming Strategy

The streaming endpoint emits server-sent events with these event names:

- `conversation.started`
- `message.delta`
- `agent.updated`
- `run.item`
- `message.completed`
- `error`
- `done`

The iOS client parses those events directly with `URLSession.bytes`.

The client validates restored `conversation_id` values against `GET /api/conversations/{conversation_id}` before it reuses a cached transcript snapshot.

## Tradeoffs

- The backend is fully runnable and tested in this environment; the iOS project is scaffolded and documented but not compiled here because Xcode and the Apple toolchain are unavailable on Windows.
- A macOS CI workflow now runs `swift test --package-path ios` for the stream parser and an `xcodebuild` smoke build for the hand-authored Xcode project.
- Guardrails ship as deterministic examples rather than LLM-based moderation flows. That keeps the system cheap, legible, and easy to extend.
- MCP support is implemented in the backend runtime and documented with examples, but no MCP server is enabled by default.
