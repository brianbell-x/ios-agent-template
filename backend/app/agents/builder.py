from __future__ import annotations

from contextlib import AsyncExitStack, asynccontextmanager
from dataclasses import dataclass
from typing import Any

from agents import Agent
from agents.mcp import MCPServerStdio, MCPServerStreamableHttp

from app.agents.catalog import AgentCatalog
from app.agents.definitions import AgentDefinition, MCPServerReference
from app.agents.extensions import ExtensionRegistry
from app.core.config import Settings


@dataclass(slots=True)
class BuiltAgent:
    agent: Agent[Any]


class AgentFactory:
    def __init__(
        self,
        *,
        settings: Settings,
        catalog: AgentCatalog,
        registry: ExtensionRegistry,
    ):
        self._settings = settings
        self._catalog = catalog
        self._registry = registry

    @asynccontextmanager
    async def lifecycle(self, agent_id: str):
        exit_stack = AsyncExitStack()
        cache: dict[str, Agent[Any]] = {}
        try:
            agent = await self._build_agent(agent_id, exit_stack, cache)
            yield BuiltAgent(agent=agent)
        finally:
            await exit_stack.aclose()

    async def _build_agent(
        self,
        agent_id: str,
        exit_stack: AsyncExitStack,
        cache: dict[str, Agent[Any]],
    ) -> Agent[Any]:
        cached = cache.get(agent_id)
        if cached is not None:
            return cached

        definition = self._catalog.get(agent_id)
        agent = Agent(
            name=definition.name,
            handoff_description=definition.handoff_description,
            instructions=self._resolve_instructions(definition),
            model=definition.model or self._settings.default_model,
            tools=[
                self._registry.build_tool(spec)
                for spec in definition.tools
                if spec.enabled
            ]
            + [
                self._registry.build_hosted_mcp_tool(spec)
                for spec in definition.hosted_mcp_tools
            ],
            handoffs=[],
            input_guardrails=[
                self._registry.build_input_guardrail(spec)
                for spec in definition.input_guardrails
                if spec.enabled
            ],
            output_guardrails=[
                self._registry.build_output_guardrail(spec)
                for spec in definition.output_guardrails
                if spec.enabled
            ],
            mcp_servers=await self._build_mcp_servers(definition, exit_stack),
            model_settings=self._registry.model_settings(definition.model_settings),
        )
        cache[agent_id] = agent
        agent.handoffs = [
            await self._build_agent(handoff_id, exit_stack, cache)
            for handoff_id in definition.handoffs
        ]
        return agent

    def _resolve_instructions(self, definition: AgentDefinition) -> str:
        if definition.instructions is not None:
            return definition.instructions
        source_path = definition.source_path
        if source_path is None:
            raise ValueError(f"Agent '{definition.id}' is missing source_path")
        config_root = source_path.parent.parent
        instructions_path = (config_root / definition.instructions_file).resolve()
        return instructions_path.read_text(encoding="utf-8").strip()

    async def _build_mcp_servers(
        self,
        definition: AgentDefinition,
        exit_stack: AsyncExitStack,
    ) -> list[Any]:
        servers: list[Any] = []
        for spec in definition.mcp_servers:
            server = self._create_mcp_server(spec)
            servers.append(await exit_stack.enter_async_context(server))
        return servers

    def _create_mcp_server(self, spec: MCPServerReference) -> Any:
        if spec.transport == "stdio":
            return MCPServerStdio(
                name=spec.name,
                params={"command": spec.command, "args": spec.args},
                require_approval=spec.require_approval,
            )
        if spec.transport == "streamable_http":
            params: dict[str, Any] = {"url": spec.url, "headers": spec.headers}
            if spec.timeout:
                params["timeout"] = spec.timeout
            return MCPServerStreamableHttp(
                name=spec.name,
                params=params,
                require_approval=spec.require_approval,
            )
        raise ValueError(f"Unsupported MCP transport: {spec.transport}")
