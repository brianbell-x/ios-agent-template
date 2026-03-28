from __future__ import annotations

from pathlib import Path

import pytest

from app.agents.builder import AgentConfigError, AgentFactory
from app.agents.catalog import AgentCatalog
from app.agents.extensions import ExtensionRegistry
from app.core.config import Settings


def test_catalog_loads_default_agent(catalog) -> None:
    default_agent = catalog.get("default")

    assert default_agent.name == "Assistant"
    assert default_agent.handoffs == ["planner", "researcher"]
    assert default_agent.tools[0].id == "current_time"


async def test_agent_factory_builds_default_agent(agent_factory) -> None:
    async with agent_factory.lifecycle("default") as built:
        agent = built.agent

    assert agent.name == "Assistant"
    assert built.config_version
    assert [handoff.name for handoff in agent.handoffs] == [
        "Planning Specialist",
        "Research Specialist",
    ]
    assert len(agent.tools) == 1
    assert len(agent.input_guardrails) == 1
    assert len(agent.output_guardrails) == 1


@pytest.mark.asyncio
async def test_agent_factory_fails_fast_on_unknown_tool(tmp_path: Path, settings: Settings) -> None:
    config_dir = tmp_path / "agents"
    config_dir.mkdir()
    (config_dir / "broken.yaml").write_text(
        "\n".join(
            [
                "id: broken",
                "name: Broken Agent",
                "instructions: test",
                "tools:",
                "  - id: missing_tool",
            ]
        ),
        encoding="utf-8",
    )
    catalog = AgentCatalog(config_dir)
    registry = ExtensionRegistry(settings)
    factory = AgentFactory(
        settings=Settings(
            agents_config_dir=config_dir,
            sessions_db_path=settings.sessions_db_path,
            default_agent_id="broken",
        ),
        catalog=catalog,
        registry=registry,
    )

    with pytest.raises(AgentConfigError):
        await factory.start()
