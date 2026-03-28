# iOS Chat Agent

Production-style iOS chat app backed by a configurable OpenAI Agents SDK service.

## What ships here

- `ios/`: a SwiftUI iOS app with a transcript-first chat interface, bottom composer, streaming assistant updates, retry handling, and local transcript restore
- `backend/`: a FastAPI service that brokers every chat turn through the OpenAI Agents SDK
- `shared/openapi.json`: exported API contract from FastAPI
- `shared/chat-stream-contract.json`: documented SSE event contract
- `docs/`: architecture notes and the frontend design brief

## Architecture

The public API stays deliberately small:

- `POST /api/chat`
- `POST /api/chat/stream`
- `GET /api/health`
- `GET /api/conversations/{conversation_id}`

The frontend stays generic. Agent behavior is configured server-side through YAML plus small Python registries for:

- model and instructions
- tools
- handoffs
- input and output guardrails
- sessions
- MCP servers and hosted MCP tools

That keeps the iOS app stable while the backend agent wiring evolves.

At startup, the backend now validates and builds the full configured agent graph once. That catches bad tool ids, guardrail ids, handoff references, missing instruction files, and invalid model settings before traffic hits the service.

## Backend Setup

Requirements:

- Python 3.11+
- `uv`
- `OPENAI_API_KEY`

Steps:

1. `cd backend`
2. `cp .env.example .env`
3. Fill in `OPENAI_API_KEY` in `backend/.env`
4. `uv sync --extra dev`
5. `uv run uvicorn app.main:app --reload`

Important defaults:

- `CHAT_AGENT_SESSION_HISTORY_LIMIT=40` caps backend session retrieval
- `ChatLocalTranscriptLimit=40` caps the persisted iOS transcript snapshot

Health check:

- `http://127.0.0.1:8000/api/health`

Optional smoke test after the server is running:

- `uv run python scripts/smoke_chat.py`

## iOS Setup

Requirements:

- Xcode 15+ on macOS
- iOS 17+ deployment target

Steps:

1. Open [ios/ChatAgent.xcodeproj](./ios/ChatAgent.xcodeproj)
2. Select the `ChatAgent` scheme
3. Update the bundle identifier and signing team
4. Run the app in the simulator

The default backend URL in [ios/ChatAgent/Info.plist](./ios/ChatAgent/Info.plist) is `http://127.0.0.1:8000`.

Notes:

- That works for simulator-based local development.
- For a physical device, replace `ChatBackendBaseURL` with a reachable host IP or tunnel.
- On launch, the app validates any restored `conversation_id` against the backend before reusing it.

## Customizing Agents

Primary agent definitions live in:

- [default.yaml](./backend/config/agents/default.yaml)
- [planner.yaml](./backend/config/agents/planner.yaml)
- [researcher.yaml](./backend/config/agents/researcher.yaml)

Extension seams live in:

- [builder.py](./backend/app/agents/builder.py)
- [extensions.py](./backend/app/agents/extensions.py)

Typical changes:

1. Update model or instructions in YAML.
2. Add a new tool or guardrail factory in `extensions.py`.
3. Reference it from an agent YAML file.
4. Restart the backend.

MCP examples are included in:

- [mcp-http.example.yaml](./backend/config/agents/examples/mcp-http.example.yaml)
- [hosted-mcp-tool.example.yaml](./backend/config/agents/examples/hosted-mcp-tool.example.yaml)

Shared stream contract artifacts are exported to:

- [openapi.json](./shared/openapi.json)
- [chat-stream-contract.json](./shared/chat-stream-contract.json)
- [chat-stream-fixture.sse](./shared/chat-stream-fixture.sse)

## Verification

Completed in this environment:

- `uv sync --extra dev`
- `uv run pytest`
- `uv run python scripts/export_openapi.py`
- direct constructor validation for SDK MCP server adapters
- JSON/plist/Xcode metadata validation

Not completed in this environment:

- Xcode build
- iOS simulator run
- `swift test --package-path ios`

This session ran on Windows without the Apple toolchain, so the iOS project is scaffolded and documented but not compiled here.

Machine-checked macOS verification is included in:

- [.github/workflows/ios-smoke.yml](./.github/workflows/ios-smoke.yml)

## Repository Layout

- `ios/`: SwiftUI client and Xcode project
- `backend/`: FastAPI service, agent config, tests, and scripts
- `shared/`: exported API contract
- `docs/`: architecture and design notes

## Important Tradeoffs

- The API contract is intentionally chat-shaped instead of mirroring the full Agents SDK surface.
- The default session strategy is `SQLiteSession`, so the backend preserves turn state without asking the client to resend transcript history.
- The backend validates agent configuration at startup and reuses the built agent graph across requests, including MCP connection scope.
- The iOS app clears stale local transcript state if the backend cannot confirm the saved conversation still exists.
- Guardrails ship as deterministic examples to keep the system cheap and legible.
- MCP support is implemented and documented, but disabled by default until a developer supplies a concrete server.
