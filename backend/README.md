# Backend

FastAPI backend for the iOS chat agent template.

It exposes:

- `POST /api/chat` for a standard request-response turn
- `POST /api/chat/stream` for server-sent-event streaming
- `GET /api/health` for a lightweight health check

The backend keeps the public API chat-shaped while loading agent behavior from YAML and local Python registries for tools, handoffs, guardrails, and MCP wiring.
