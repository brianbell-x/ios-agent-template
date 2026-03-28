from __future__ import annotations


def test_catalog_loads_default_agent(catalog) -> None:
    default_agent = catalog.get("default")

    assert default_agent.name == "Template Assistant"
    assert default_agent.handoffs == ["planner", "researcher"]
    assert default_agent.tools[0].id == "current_time"


async def test_agent_factory_builds_default_agent(agent_factory) -> None:
    async with agent_factory.lifecycle("default") as built:
        agent = built.agent

    assert agent.name == "Template Assistant"
    assert [handoff.name for handoff in agent.handoffs] == [
        "Planning Specialist",
        "Research Specialist",
    ]
    assert len(agent.tools) == 1
    assert len(agent.input_guardrails) == 1
    assert len(agent.output_guardrails) == 1
