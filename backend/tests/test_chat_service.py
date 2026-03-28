from __future__ import annotations

from types import SimpleNamespace

import pytest
from openai.types.responses import ResponseTextDeltaEvent

from app.agents.service import ChatService
from app.schemas.chat import ChatCompletionRequest


class FakeRunner:
    async def run(self, agent, input, *, session):
        return SimpleNamespace(
            final_output="Hello from the backend",
            last_response_id="resp_123",
            last_agent=SimpleNamespace(name="Template Assistant"),
        )

    def run_streamed(self, agent, input, *, session):
        return FakeStreamingResult()


class FakeStreamingResult:
    final_output = "Hello streamed"
    last_response_id = "resp_stream_123"
    last_agent = SimpleNamespace(name="Planning Specialist")

    async def stream_events(self):
        yield SimpleNamespace(
            type="raw_response_event",
            data=ResponseTextDeltaEvent(
                type="response.output_text.delta",
                content_index=0,
                delta="Hello",
                item_id="item_1",
                logprobs=[],
                output_index=0,
                sequence_number=0,
            ),
        )
        yield SimpleNamespace(
            type="agent_updated_stream_event",
            new_agent=SimpleNamespace(name="Planning Specialist"),
        )
        yield SimpleNamespace(
            type="run_item_stream_event",
            name="tool_called",
            item=SimpleNamespace(type="tool_call_item"),
        )


@pytest.mark.asyncio
async def test_chat_service_creates_response(settings, agent_factory) -> None:
    service = ChatService(settings=settings, agent_factory=agent_factory, runner=FakeRunner())

    response = await service.respond(ChatCompletionRequest(message="Hello"))

    assert response.conversation_id
    assert response.message.content == "Hello from the backend"
    assert response.response_id == "resp_123"


@pytest.mark.asyncio
async def test_chat_service_streams_deltas(settings, agent_factory) -> None:
    service = ChatService(settings=settings, agent_factory=agent_factory, runner=FakeRunner())

    envelopes = [
        envelope
        async for envelope in service.stream(ChatCompletionRequest(message="Hello"))
    ]

    assert [envelope.event for envelope in envelopes] == [
        "conversation.started",
        "message.delta",
        "agent.updated",
        "run.item",
        "message.completed",
        "done",
    ]
    assert envelopes[1].data["delta"] == "Hello"
    assert envelopes[4].data["content"] == "Hello streamed"
