from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_prefix="CHAT_TEMPLATE_",
        extra="ignore",
    )

    app_name: str = "iOS Chat Agent Template Backend"
    environment: str = "development"
    host: str = "127.0.0.1"
    port: int = 8000
    public_base_url: str = "http://127.0.0.1:8000"
    default_agent_id: str = "default"
    default_model: str = "gpt-5-mini"
    openai_api_shape: str = Field(default="responses")
    agents_config_dir: Path = Field(default=BACKEND_DIR / "config" / "agents")
    sessions_db_path: Path = Field(default=BACKEND_DIR / ".data" / "agent_sessions.sqlite3")

    def ensure_runtime_directories(self) -> None:
        self.sessions_db_path.parent.mkdir(parents=True, exist_ok=True)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
