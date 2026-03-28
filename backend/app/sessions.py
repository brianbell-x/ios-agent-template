from __future__ import annotations

from agents import SQLiteSession, SessionSettings

from app.core.config import Settings


class SessionFactory:
    def __init__(self, settings: Settings):
        self._db_path = settings.sessions_db_path
        self._history_limit = settings.session_history_limit
        self._session_settings = SessionSettings(limit=settings.session_history_limit)

    @property
    def history_limit(self) -> int:
        return self._history_limit

    def create(self, conversation_id: str) -> SQLiteSession:
        return SQLiteSession(
            conversation_id,
            self._db_path,
            session_settings=self._session_settings,
        )

    async def conversation_exists(self, conversation_id: str) -> bool:
        session = self.create(conversation_id)
        items = await session.get_items(limit=1)
        return bool(items)
