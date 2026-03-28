# Backend

FastAPI backend for the iOS chat agent app.

It exposes:

- `POST /api/chat` for a standard request-response turn
- `POST /api/chat/stream` for server-sent-event streaming
- `GET /api/health` for a lightweight health check
- `GET /api/conversations/{conversation_id}` for backend session validation

The backend keeps the public API chat-shaped while loading agent behavior from YAML and local Python registries for tools, handoffs, guardrails, sessions, and MCP wiring.

At startup, the backend validates and builds the configured agent graph once, then reuses that runtime across requests.
