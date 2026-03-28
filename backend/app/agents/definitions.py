from __future__ import annotations

from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator


class ToolReference(BaseModel):
    id: str
    enabled: bool = True
    settings: dict[str, Any] = Field(default_factory=dict)
    name_override: str | None = None
    description_override: str | None = None


class GuardrailReference(BaseModel):
    id: str
    enabled: bool = True
    settings: dict[str, Any] = Field(default_factory=dict)
    run_in_parallel: bool | None = None


class HostedMCPToolReference(BaseModel):
    server_label: str
    server_url: str | None = None
    connector_id: str | None = None
    authorization_env: str | None = None
    require_approval: str | bool | dict[str, Any] | None = None

    @model_validator(mode="after")
    def validate_location(self) -> "HostedMCPToolReference":
        if not self.server_url and not self.connector_id:
            raise ValueError("Hosted MCP tools require either server_url or connector_id")
        return self


class MCPServerReference(BaseModel):
    name: str
    transport: Literal["stdio", "streamable_http"]
    url: str | None = None
    command: str | None = None
    args: list[str] = Field(default_factory=list)
    headers: dict[str, str] = Field(default_factory=dict)
    timeout: int | None = 10
    require_approval: str | bool | dict[str, Any] | None = None

    @model_validator(mode="after")
    def validate_transport(self) -> "MCPServerReference":
        if self.transport == "stdio" and not self.command:
            raise ValueError("stdio MCP servers require command")
        if self.transport == "streamable_http" and not self.url:
            raise ValueError("streamable_http MCP servers require url")
        return self


class AgentDefinition(BaseModel):
    id: str
    name: str
    model: str | None = None
    description: str | None = None
    handoff_description: str | None = None
    instructions: str | None = None
    instructions_file: str | None = None
    tools: list[ToolReference] = Field(default_factory=list)
    handoffs: list[str] = Field(default_factory=list)
    input_guardrails: list[GuardrailReference] = Field(default_factory=list)
    output_guardrails: list[GuardrailReference] = Field(default_factory=list)
    hosted_mcp_tools: list[HostedMCPToolReference] = Field(default_factory=list)
    mcp_servers: list[MCPServerReference] = Field(default_factory=list)
    model_settings: dict[str, Any] = Field(default_factory=dict)
    source_path: Path | None = Field(default=None, exclude=True)

    @model_validator(mode="after")
    def validate_instructions(self) -> "AgentDefinition":
        if not self.instructions and not self.instructions_file:
            raise ValueError("Each agent requires instructions or instructions_file")
        return self
