from __future__ import annotations

import os
from contextlib import asynccontextmanager

from agents import set_default_openai_api, set_default_openai_key
from fastapi import FastAPI

from app.agents.builder import AgentFactory
from app.agents.catalog import AgentCatalog
from app.agents.extensions import ExtensionRegistry
from app.agents.service import ChatService
from app.api.routes_chat import router as chat_router
from app.core.config import Settings, get_settings
from app.sessions import SessionFactory


def configure_openai(settings: Settings) -> None:
    if settings.openai_api_shape == "chat_completions":
        set_default_openai_api("chat_completions")

    api_key = os.environ.get("OPENAI_API_KEY")
    if api_key:
        set_default_openai_key(api_key)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    settings.ensure_runtime_directories()
    configure_openai(settings)

    catalog = AgentCatalog(settings.agents_config_dir)
    registry = ExtensionRegistry(settings)
    agent_factory = AgentFactory(settings=settings, catalog=catalog, registry=registry)
    await agent_factory.start()
    session_factory = SessionFactory(settings)
    chat_service = ChatService(
        settings=settings,
        agent_factory=agent_factory,
        session_factory=session_factory,
    )

    app.state.settings = settings
    app.state.chat_service = chat_service
    try:
        yield
    finally:
        await agent_factory.close()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.include_router(chat_router, prefix="/api", tags=["chat"])
    return app


app = create_app()
