from __future__ import annotations

import argparse
import json

import httpx


def main() -> None:
    parser = argparse.ArgumentParser(description="Smoke test the backend chat endpoint.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--message", default="Say hello in one short sentence.")
    parser.add_argument("--agent-id", default="default")
    args = parser.parse_args()

    payload = {
        "message": args.message,
        "agent_id": args.agent_id,
    }
    response = httpx.post(f"{args.base_url}/api/chat", json=payload, timeout=60.0)
    response.raise_for_status()
    print(json.dumps(response.json(), indent=2))


if __name__ == "__main__":
    main()
