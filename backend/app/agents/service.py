from __future__ import annotations

from dataclasses import dataclass
from typing import Any, AsyncIterator, Protocol
from uuid import uuid4

from agents import Runner, SQLiteSession
from openai.types.responses import ResponseTextDeltaEvent

from app.agents.builder import AgentFactory
from app.core.config import Settings
from app.schemas.chat import ChatCompletionRequest, ChatCompletionResponse, ChatMessagePayload


@dataclass(frozen=True, slots=True)
class StreamEnvelope:
    event: str
    data: dict[str, Any]


class RunnerProtocol(Protocol):
    async def run(self, *args: Any, **kwargs: Any) -> Any: ...

    def run_streamed(self, *args: Any, **kwargs: Any) -> Any: ...


class AgentsRunner:
    async def run(self, *args: Any, **kwargs: Any) -> Any:
        return await Runner.run(*args, **kwargs)

    def run_streamed(self, *args: Any, **kwargs: Any) -> Any:
        return Runner.run_streamed(*args, **kwargs)


class ChatService:
    def __init__(
        self,
        *,
        settings: Settings,
        agent_factory: AgentFactory,
        runner: RunnerProtocol | None = None,
    ):
        self._settings = settings
        self._agent_factory = agent_factory
        self._runner = runner or AgentsRunner()

    async def respond(self, request: ChatCompletionRequest) -> ChatCompletionResponse:
        agent_id = request.agent_id or self._settings.default_agent_id
        conversation_id = request.conversation_id or uuid4().hex
        session = SQLiteSession(conversation_id, self._settings.sessions_db_path)
        async with self._agent_factory.lifecycle(agent_id) as built_agent:
            result = await self._runner.run(
                built_agent.agent,
                request.message,
                session=session,
            )
        return ChatCompletionResponse(
            conversation_id=conversation_id,
            agent_id=agent_id,
            final_agent_name=result.last_agent.name,
            response_id=result.last_response_id,
            message=ChatMessagePayload(role="assistant", content=str(result.final_output)),
        )

    async def stream(self, request: ChatCompletionRequest) -> AsyncIterator[StreamEnvelope]:
        agent_id = request.agent_id or self._settings.default_agent_id
        conversation_id = request.conversation_id or uuid4().hex
        session = SQLiteSession(conversation_id, self._settings.sessions_db_path)

        yield StreamEnvelope(
            event="conversation.started",
            data={"conversation_id": conversation_id, "agent_id": agent_id},
        )

        async with self._agent_factory.lifecycle(agent_id) as built_agent:
            result = self._runner.run_streamed(
                built_agent.agent,
                request.message,
                session=session,
            )
            async for event in result.stream_events():
                if (
                    event.type == "raw_response_event"
                    and isinstance(event.data, ResponseTextDeltaEvent)
                ):
                    yield StreamEnvelope(
                        event="message.delta",
                        data={"delta": event.data.delta},
                    )
                    continue

                if event.type == "agent_updated_stream_event":
                    yield StreamEnvelope(
                        event="agent.updated",
                        data={"agent_name": event.new_agent.name},
                    )
                    continue

                if event.type == "run_item_stream_event" and event.name in {
                    "tool_called",
                    "tool_output",
                }:
                    yield StreamEnvelope(
                        event="run.item",
                        data={"name": event.name, "item_type": event.item.type},
                    )

            yield StreamEnvelope(
                event="message.completed",
                data={
                    "conversation_id": conversation_id,
                    "agent_id": agent_id,
                    "final_agent_name": result.last_agent.name,
                    "response_id": result.last_response_id,
                    "content": str(result.final_output),
                },
            )
            yield StreamEnvelope(event="done", data={})
