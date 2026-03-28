# Architecture

## Boundaries

- `ios/` is a thin SwiftUI chat client.
- `backend/` owns all OpenAI Agents SDK behavior.
- `shared/openapi.json` is the stable contract artifact exported from FastAPI.

## Stable API Contract

The public backend API is intentionally narrow:

- `POST /api/chat`
- `POST /api/chat/stream`
- `GET /api/health`

The request contract stays chat-shaped:

- `message`
- optional `conversation_id`
- optional `agent_id`

This keeps the iOS app decoupled from SDK churn. Model choice, tools, handoffs, guardrails, sessions, and MCP wiring stay inside backend configuration and Python code.

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

## Session Strategy

The template uses `SQLiteSession` from the Agents SDK and keys each server-side conversation by `conversation_id`.

Why this default:

- it preserves multi-turn context without forcing the client to resend transcript history
- it is easy to understand locally
- it can be swapped later for another `Session` implementation or an OpenAI-managed continuation strategy

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

## Tradeoffs

- The backend is fully runnable and tested in this environment; the iOS project is scaffolded and documented but not compiled here because Xcode and the Apple toolchain are unavailable on Windows.
- Guardrails ship as deterministic examples rather than LLM-based moderation flows. That keeps the template cheap, legible, and easy to extend.
- MCP support is implemented in the backend runtime and documented with examples, but no MCP server is enabled by default.
