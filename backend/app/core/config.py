from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        env_prefix="CHAT_AGENT_",
        extra="ignore",
        populate_by_name=True,
    )

    app_name: str = "Chat Agent Backend"
    environment: str = "development"
    default_agent_id: str = "default"
    default_model: str = "gpt-5-mini"
    openai_api_key: str | None = Field(default=None, validation_alias="OPENAI_API_KEY")
    disable_tracing: bool = Field(default=False, validation_alias="OPENAI_AGENTS_DISABLE_TRACING")
    openai_api_shape: str = Field(default="responses")
    agents_config_dir: Path = Field(default=BACKEND_DIR / "config" / "agents")
    sessions_db_path: Path = Field(default=BACKEND_DIR / ".data" / "agent_sessions.sqlite3")
    session_history_limit: int = 40

    def ensure_runtime_directories(self) -> None:
        self.sessions_db_path.parent.mkdir(parents=True, exist_ok=True)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
