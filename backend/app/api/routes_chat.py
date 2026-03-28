from __future__ import annotations
from collections.abc import AsyncIterator

from agents import InputGuardrailTripwireTriggered, OutputGuardrailTripwireTriggered
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse

from app.agents.service import ChatService
from app.schemas.chat import (
    ChatCompletionRequest,
    ChatCompletionResponse,
    ConversationStatusResponse,
    ErrorPayload,
    ErrorResponse,
    HealthResponse,
)
from app.streaming import StreamEnvelope, encode_sse, stream_contract_fixture_text


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


@router.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    service = get_chat_service(request)
    settings = request.app.state.settings
    return HealthResponse(
        status="ok",
        default_agent_id=settings.default_agent_id,
        available_agent_ids=service.available_agent_ids,
        session_history_limit=settings.session_history_limit,
        agent_config_version=service.agent_config_version,
    )


@router.get("/conversations/{conversation_id}", response_model=ConversationStatusResponse)
async def get_conversation_status(
    conversation_id: str,
    service: ChatService = Depends(get_chat_service),
) -> ConversationStatusResponse:
    return await service.conversation_status(conversation_id)


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
    except KeyError as exc:
        raise _http_error(
            status_code=400,
            code="unknown_agent",
            message=str(exc),
        ) from exc
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


@router.post(
    "/chat/stream",
    responses={
        200: {
            "content": {
                "text/event-stream": {
                    "example": stream_contract_fixture_text(session_history_limit=40),
                }
            }
        }
    },
)
async def create_chat_stream(
    payload: ChatCompletionRequest,
    service: ChatService = Depends(get_chat_service),
) -> StreamingResponse:
    async def event_stream() -> AsyncIterator[str]:
        try:
            async for envelope in service.stream(payload):
                yield encode_sse(envelope)
        except KeyError as exc:
            yield encode_sse(
                StreamEnvelope(
                    event="error",
                    data={
                        "code": "unknown_agent",
                        "message": str(exc),
                    },
                )
            )
            yield encode_sse(StreamEnvelope(event="done", data={}))
        except InputGuardrailTripwireTriggered as exc:
            yield encode_sse(
                StreamEnvelope(
                    event="error",
                    data={
                        "code": "input_guardrail_triggered",
                        "message": "The request was blocked by an input guardrail.",
                        "guardrail": exc.guardrail_result.guardrail.get_name(),
                    },
                )
            )
            yield encode_sse(StreamEnvelope(event="done", data={}))
        except OutputGuardrailTripwireTriggered as exc:
            yield encode_sse(
                StreamEnvelope(
                    event="error",
                    data={
                        "code": "output_guardrail_triggered",
                        "message": "The agent output was blocked by an output guardrail.",
                        "guardrail": exc.guardrail_result.guardrail.get_name(),
                    },
                )
            )
            yield encode_sse(StreamEnvelope(event="done", data={}))
        except Exception:
            yield encode_sse(
                StreamEnvelope(
                    event="error",
                    data={
                        "code": "backend_error",
                        "message": "The backend could not complete the request.",
                    },
                )
            )
            yield encode_sse(StreamEnvelope(event="done", data={}))

    return StreamingResponse(event_stream(), media_type="text/event-stream")
