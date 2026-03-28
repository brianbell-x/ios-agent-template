from __future__ import annotations

from pathlib import Path

import pytest
import pytest_asyncio

from app.agents.builder import AgentFactory
from app.agents.catalog import AgentCatalog
from app.agents.extensions import ExtensionRegistry
from app.core.config import Settings


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    return Settings(
        sessions_db_path=tmp_path / "sessions.sqlite3",
        agents_config_dir=Path(__file__).resolve().parents[1] / "config" / "agents",
        default_agent_id="default",
    )


@pytest.fixture
def catalog(settings: Settings) -> AgentCatalog:
    return AgentCatalog(settings.agents_config_dir)


@pytest.fixture
def registry(settings: Settings) -> ExtensionRegistry:
    return ExtensionRegistry(settings)


@pytest_asyncio.fixture
async def agent_factory(settings: Settings, catalog: AgentCatalog, registry: ExtensionRegistry) -> AgentFactory:
    factory = AgentFactory(settings=settings, catalog=catalog, registry=registry)
    await factory.start()
    try:
        yield factory
    finally:
        await factory.close()
