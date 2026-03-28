from __future__ import annotations

from typing import Any, AsyncIterator, Protocol
from uuid import uuid4

from agents import Runner
from openai.types.responses import ResponseTextDeltaEvent

from app.agents.builder import AgentFactory
from app.core.config import Settings
from app.schemas.chat import (
    ChatCompletionRequest,
    ChatCompletionResponse,
    ChatMessagePayload,
    ConversationStatusResponse,
)
from app.sessions import SessionFactory
from app.streaming import StreamEnvelope


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
        session_factory: SessionFactory,
        runner: RunnerProtocol | None = None,
    ):
        self._settings = settings
        self._agent_factory = agent_factory
        self._session_factory = session_factory
        self._runner = runner or AgentsRunner()

    @property
    def available_agent_ids(self) -> list[str]:
        return self._agent_factory.available_agent_ids()

    @property
    def agent_config_version(self) -> str:
        return self._agent_factory.config_version

    async def respond(self, request: ChatCompletionRequest) -> ChatCompletionResponse:
        agent_id = request.agent_id or self._settings.default_agent_id
        conversation_id = request.conversation_id or uuid4().hex
        session = self._session_factory.create(conversation_id)
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
        session = self._session_factory.create(conversation_id)

        yield StreamEnvelope(
            event="conversation.started",
            data={
                "conversation_id": conversation_id,
                "agent_id": agent_id,
                "session_history_limit": self._session_factory.history_limit,
            },
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
                    "session_history_limit": self._session_factory.history_limit,
                },
            )
            yield StreamEnvelope(event="done", data={})

    async def conversation_status(self, conversation_id: str) -> ConversationStatusResponse:
        return ConversationStatusResponse(
            conversation_id=conversation_id,
            exists=await self._session_factory.conversation_exists(conversation_id),
            session_history_limit=self._session_factory.history_limit,
        )
