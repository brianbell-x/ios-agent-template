from __future__ import annotations

import asyncio
from contextlib import AsyncExitStack, asynccontextmanager
from dataclasses import dataclass
from typing import Any

from agents import Agent
from agents.mcp import MCPServerStdio, MCPServerStreamableHttp

from app.agents.catalog import AgentCatalog
from app.agents.definitions import AgentDefinition, MCPServerReference
from app.agents.extensions import ExtensionRegistry
from app.core.config import Settings


class AgentConfigError(ValueError):
    """Raised when agent configuration cannot be resolved safely."""


@dataclass(slots=True)
class BuiltAgent:
    agent: Agent[Any]
    config_version: str


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
        self._agents: dict[str, Agent[Any]] = {}
        self._config_version: str | None = None
        self._exit_stack: AsyncExitStack | None = None
        self._lock = asyncio.Lock()

    @asynccontextmanager
    async def lifecycle(self, agent_id: str):
        await self.start()
        yield BuiltAgent(
            agent=self.get(agent_id),
            config_version=self.config_version,
        )

    @property
    def config_version(self) -> str:
        return self._config_version or ""

    def available_agent_ids(self) -> list[str]:
        return self._catalog.list_ids()

    async def start(self) -> None:
        async with self._lock:
            self._catalog.reload()
            if self._agents and self._config_version == self._catalog.version:
                return

            self._validate_catalog()

            next_exit_stack = AsyncExitStack()
            next_agents: dict[str, Agent[Any]] = {}
            try:
                for agent_id in self._catalog.list_ids():
                    await self._build_agent(agent_id, next_exit_stack, next_agents)
            except Exception:
                await next_exit_stack.aclose()
                raise

            current_exit_stack = self._exit_stack
            self._exit_stack = next_exit_stack
            self._agents = next_agents
            self._config_version = self._catalog.version

            if current_exit_stack is not None:
                await current_exit_stack.aclose()

    async def close(self) -> None:
        async with self._lock:
            current_exit_stack = self._exit_stack
            self._exit_stack = None
            self._agents = {}
            self._config_version = None
            if current_exit_stack is not None:
                await current_exit_stack.aclose()

    def get(self, agent_id: str) -> Agent[Any]:
        try:
            return self._agents[agent_id]
        except KeyError as exc:
            available = ", ".join(sorted(self._agents))
            raise KeyError(f"Unknown agent '{agent_id}'. Available: {available}") from exc

    def _validate_catalog(self) -> None:
        available_agent_ids = set(self._catalog.list_ids())
        for definition in self._catalog.definitions():
            try:
                self._resolve_instructions(definition)
            except FileNotFoundError as exc:
                raise AgentConfigError(
                    f"Agent '{definition.id}' instructions file was not found: {definition.instructions_file}"
                ) from exc

            for handoff_id in definition.handoffs:
                if handoff_id not in available_agent_ids:
                    raise AgentConfigError(
                        f"Agent '{definition.id}' references unknown handoff '{handoff_id}'"
                    )

            for tool in definition.tools:
                if tool.enabled and tool.id not in self._registry.tool_ids:
                    raise AgentConfigError(
                        f"Agent '{definition.id}' references unknown tool '{tool.id}'"
                    )

            for guardrail in definition.input_guardrails:
                if guardrail.enabled and guardrail.id not in self._registry.input_guardrail_ids:
                    raise AgentConfigError(
                        f"Agent '{definition.id}' references unknown input guardrail '{guardrail.id}'"
                    )

            for guardrail in definition.output_guardrails:
                if guardrail.enabled and guardrail.id not in self._registry.output_guardrail_ids:
                    raise AgentConfigError(
                        f"Agent '{definition.id}' references unknown output guardrail '{guardrail.id}'"
                    )

            try:
                self._registry.model_settings(definition.model_settings)
            except Exception as exc:
                raise AgentConfigError(
                    f"Agent '{definition.id}' has invalid model settings"
                ) from exc

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
        try:
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
        except Exception as exc:
            raise AgentConfigError(f"Failed to build agent '{definition.id}'") from exc
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
