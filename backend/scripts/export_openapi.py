from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app


def main() -> None:
    app = create_app()
    output_path = Path(__file__).resolve().parents[2] / "shared" / "openapi.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(app.openapi(), indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
