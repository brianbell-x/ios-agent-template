from __future__ import annotations

import json
from collections.abc import AsyncIterator

from agents import InputGuardrailTripwireTriggered, OutputGuardrailTripwireTriggered
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse

from app.agents.service import ChatService, StreamEnvelope
from app.schemas.chat import (
    ChatCompletionRequest,
    ChatCompletionResponse,
    ErrorPayload,
    ErrorResponse,
    HealthResponse,
)


router = APIRouter()


def get_chat_service(request: Request) -> ChatService:
    return request.app.state.chat_service


def _http_error(
    *,
    status_code: int,
    code: str,
    message: str,
    details: dict | None = None,
) -> HTTPException:
    payload = ErrorResponse(error=ErrorPayload(code=code, message=message, details=details))
    return HTTPException(status_code=status_code, detail=payload.model_dump())


def _encode_sse(envelope: StreamEnvelope) -> str:
    payload = json.dumps(envelope.data, default=str)
    return f"event: {envelope.event}\ndata: {payload}\n\n"


@router.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    settings = request.app.state.settings
    return HealthResponse(status="ok", default_agent_id=settings.default_agent_id)


@router.post(
    "/chat",
    response_model=ChatCompletionResponse,
    responses={
        400: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def create_chat_response(
    payload: ChatCompletionRequest,
    service: ChatService = Depends(get_chat_service),
) -> ChatCompletionResponse:
    try:
        return await service.respond(payload)
    except InputGuardrailTripwireTriggered as exc:
        raise _http_error(
            status_code=400,
            code="input_guardrail_triggered",
            message="The request was blocked by an input guardrail.",
            details={"guardrail": exc.guardrail_result.guardrail.get_name()},
        ) from exc
    except OutputGuardrailTripwireTriggered as exc:
        raise _http_error(
            status_code=400,
            code="output_guardrail_triggered",
            message="The agent output was blocked by an output guardrail.",
            details={"guardrail": exc.guardrail_result.guardrail.get_name()},
        ) from exc
    except Exception as exc:
        raise _http_error(
            status_code=500,
            code="backend_error",
            message="The backend could not complete the request.",
        ) from exc


@router.post("/chat/stream")
async def create_chat_stream(
    payload: ChatCompletionRequest,
    service: ChatService = Depends(get_chat_service),
) -> StreamingResponse:
    async def event_stream() -> AsyncIterator[str]:
        try:
            async for envelope in service.stream(payload):
                yield _encode_sse(envelope)
        except InputGuardrailTripwireTriggered as exc:
            yield _encode_sse(
                StreamEnvelope(
                    event="error",
                    data={
                        "code": "input_guardrail_triggered",
                        "message": "The request was blocked by an input guardrail.",
                        "guardrail": exc.guardrail_result.guardrail.get_name(),
                    },
                )
            )
            yield _encode_sse(StreamEnvelope(event="done", data={}))
        except OutputGuardrailTripwireTriggered as exc:
            yield _encode_sse(
                StreamEnvelope(
                    event="error",
                    data={
                        "code": "output_guardrail_triggered",
                        "message": "The agent output was blocked by an output guardrail.",
                        "guardrail": exc.guardrail_result.guardrail.get_name(),
                    },
                )
            )
            yield _encode_sse(StreamEnvelope(event="done", data={}))
        except Exception:
            yield _encode_sse(
                StreamEnvelope(
                    event="error",
                    data={
                        "code": "backend_error",
                        "message": "The backend could not complete the request.",
                    },
                )
            )
            yield _encode_sse(StreamEnvelope(event="done", data={}))

    return StreamingResponse(event_stream(), media_type="text/event-stream")
