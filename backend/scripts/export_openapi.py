from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app
from app.core.config import get_settings
from app.streaming import stream_contract_document, stream_contract_fixture_text


def main() -> None:
    app = create_app()
    shared_dir = Path(__file__).resolve().parents[2] / "shared"
    shared_dir.mkdir(parents=True, exist_ok=True)
    settings = get_settings()

    (shared_dir / "openapi.json").write_text(
        json.dumps(app.openapi(), indent=2),
        encoding="utf-8",
    )
    (shared_dir / "chat-stream-contract.json").write_text(
        json.dumps(stream_contract_document(settings.session_history_limit), indent=2),
        encoding="utf-8",
    )
    (shared_dir / "chat-stream-fixture.sse").write_text(
        stream_contract_fixture_text(settings.session_history_limit),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
