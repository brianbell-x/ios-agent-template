from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class ChatCompletionRequest(BaseModel):
    message: str = Field(min_length=1, max_length=20_000)
    conversation_id: str | None = None
    agent_id: str | None = None


class ChatMessagePayload(BaseModel):
    role: Literal["assistant"]
    content: str


class ChatCompletionResponse(BaseModel):
    conversation_id: str
    agent_id: str
    final_agent_name: str
    response_id: str | None = None
    message: ChatMessagePayload


class ErrorPayload(BaseModel):
    code: str
    message: str
    details: dict[str, Any] | None = None


class ErrorResponse(BaseModel):
    error: ErrorPayload


class HealthResponse(BaseModel):
    status: Literal["ok"]
    default_agent_id: str
