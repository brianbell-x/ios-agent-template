from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from app.schemas.chat import (
    AgentUpdatedEventData,
    ConversationStartedEventData,
    MessageCompletedEventData,
    MessageDeltaEventData,
    RunItemEventData,
    StreamErrorPayload,
)


@dataclass(frozen=True, slots=True)
class StreamEnvelope:
    event: str
    data: dict[str, Any]


def encode_sse(envelope: StreamEnvelope) -> str:
    payload = json.dumps(envelope.data, default=str)
    return f"event: {envelope.event}\ndata: {payload}\n\n"


def stream_contract_document(session_history_limit: int) -> dict[str, Any]:
    return {
        "content_type": "text/event-stream",
        "events": {
            "conversation.started": ConversationStartedEventData.model_json_schema(),
            "message.delta": MessageDeltaEventData.model_json_schema(),
            "agent.updated": AgentUpdatedEventData.model_json_schema(),
            "run.item": RunItemEventData.model_json_schema(),
            "message.completed": MessageCompletedEventData.model_json_schema(),
            "error": StreamErrorPayload.model_json_schema(),
            "done": {
                "title": "DoneEventData",
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        },
        "example_sequence": [
            {
                "event": "conversation.started",
                "data": ConversationStartedEventData(
                    conversation_id="demo-conversation",
                    agent_id="default",
                    session_history_limit=session_history_limit,
                ).model_dump(),
            },
            {
                "event": "message.delta",
                "data": MessageDeltaEventData(delta="Hello").model_dump(),
            },
            {
                "event": "agent.updated",
                "data": AgentUpdatedEventData(agent_name="Planning Specialist").model_dump(),
            },
            {
                "event": "run.item",
                "data": RunItemEventData(name="tool_called", item_type="tool_call_item").model_dump(),
            },
            {
                "event": "message.completed",
                "data": MessageCompletedEventData(
                    conversation_id="demo-conversation",
                    agent_id="default",
                    final_agent_name="Planning Specialist",
                    response_id="resp_demo_123",
                    content="Hello streamed",
                    session_history_limit=session_history_limit,
                ).model_dump(),
            },
            {
                "event": "done",
                "data": {},
            },
        ],
    }


def stream_contract_fixture_text(session_history_limit: int) -> str:
    contract = stream_contract_document(session_history_limit)
    return "".join(
        encode_sse(StreamEnvelope(event=item["event"], data=item["data"]))
        for item in contract["example_sequence"]
    )
