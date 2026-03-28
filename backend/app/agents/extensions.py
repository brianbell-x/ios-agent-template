from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from agents import (
    Agent,
    GuardrailFunctionOutput,
    HostedMCPTool,
    ModelSettings,
    RunContextWrapper,
    TResponseInputItem,
    function_tool,
    input_guardrail,
    output_guardrail,
)

from app.agents.definitions import GuardrailReference, HostedMCPToolReference, ToolReference
from app.core.config import Settings


SECRET_PATTERN = re.compile(r"(sk-[A-Za-z0-9]{20,}|OPENAI_API_KEY)", re.IGNORECASE)


@dataclass(frozen=True, slots=True)
class ExtensionContext:
    settings: Settings


class ToolFactory(Protocol):
    def __call__(self, spec: ToolReference, context: ExtensionContext) -> Any: ...


class GuardrailFactory(Protocol):
    def __call__(self, spec: GuardrailReference, context: ExtensionContext) -> Any: ...


def _flatten_input(input_value: str | list[TResponseInputItem]) -> str:
    if isinstance(input_value, str):
        return input_value
    return json.dumps(input_value, default=str)


def build_current_time_tool(spec: ToolReference, context: ExtensionContext) -> Any:
    default_timezone = spec.settings.get("default_timezone", "UTC")

    def current_time(timezone: str | None = None) -> str:
        """Return the current date and time.

        Args:
            timezone: IANA timezone name, for example America/Chicago.
        """

        tz_name = timezone or default_timezone
        try:
            tz = ZoneInfo(tz_name)
        except ZoneInfoNotFoundError:
            tz = ZoneInfo("UTC")
            tz_name = "UTC"
        now = datetime.now(tz).isoformat()
        return f"{now} ({tz_name})"

    return function_tool(
        current_time,
        name_override=spec.name_override,
        description_override=spec.description_override,
    )


def build_max_input_chars_guardrail(spec: GuardrailReference, context: ExtensionContext) -> Any:
    max_chars = int(spec.settings.get("max_chars", 6000))
    run_in_parallel = spec.run_in_parallel if spec.run_in_parallel is not None else False

    @input_guardrail(name=spec.id, run_in_parallel=run_in_parallel)
    async def max_input_chars(
        ctx: RunContextWrapper[None],
        agent: Agent,
        input_value: str | list[TResponseInputItem],
    ) -> GuardrailFunctionOutput:
        flattened = _flatten_input(input_value)
        return GuardrailFunctionOutput(
            output_info={"max_chars": max_chars, "observed_chars": len(flattened)},
            tripwire_triggered=len(flattened) > max_chars,
        )

    return max_input_chars


def build_secret_output_guardrail(spec: GuardrailReference, context: ExtensionContext) -> Any:
    pattern = re.compile(spec.settings.get("pattern", SECRET_PATTERN.pattern), re.IGNORECASE)

    @output_guardrail(name=spec.id)
    async def block_secret_like_output(
        ctx: RunContextWrapper[None],
        agent: Agent,
        output: Any,
    ) -> GuardrailFunctionOutput:
        text = output if isinstance(output, str) else json.dumps(output, default=str)
        return GuardrailFunctionOutput(
            output_info={"pattern": pattern.pattern},
            tripwire_triggered=bool(pattern.search(text)),
        )

    return block_secret_like_output


def build_hosted_mcp_tool(spec: HostedMCPToolReference) -> HostedMCPTool:
    tool_config: dict[str, Any] = {
        "type": "mcp",
        "server_label": spec.server_label,
    }
    if spec.server_url:
        tool_config["server_url"] = spec.server_url
    if spec.connector_id:
        tool_config["connector_id"] = spec.connector_id
    if spec.require_approval is not None:
        tool_config["require_approval"] = spec.require_approval
    if spec.authorization_env:
        tool_config["authorization"] = os.environ.get(spec.authorization_env, "")
    return HostedMCPTool(tool_config=tool_config)


class ExtensionRegistry:
    def __init__(self, settings: Settings):
        context = ExtensionContext(settings=settings)
        self._context = context
        self._tool_factories: dict[str, ToolFactory] = {
            "current_time": build_current_time_tool,
        }
        self._input_guardrail_factories: dict[str, GuardrailFactory] = {
            "max_input_chars": build_max_input_chars_guardrail,
        }
        self._output_guardrail_factories: dict[str, GuardrailFactory] = {
            "block_secret_like_output": build_secret_output_guardrail,
        }

    def build_tool(self, spec: ToolReference) -> Any:
        factory = self._tool_factories[spec.id]
        return factory(spec, self._context)

    def build_input_guardrail(self, spec: GuardrailReference) -> Any:
        factory = self._input_guardrail_factories[spec.id]
        return factory(spec, self._context)

    def build_output_guardrail(self, spec: GuardrailReference) -> Any:
        factory = self._output_guardrail_factories[spec.id]
        return factory(spec, self._context)

    def build_hosted_mcp_tool(self, spec: HostedMCPToolReference) -> HostedMCPTool:
        return build_hosted_mcp_tool(spec)

    def model_settings(self, raw: dict[str, Any]) -> ModelSettings:
        return ModelSettings(**raw)
