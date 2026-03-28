from __future__ import annotations

from pathlib import Path

import yaml

from app.agents.definitions import AgentDefinition


class AgentCatalog:
    def __init__(self, config_dir: Path):
        self._config_dir = config_dir
        self._definitions: dict[str, AgentDefinition] = {}
        self.reload()

    @property
    def config_dir(self) -> Path:
        return self._config_dir

    def reload(self) -> None:
        definitions: dict[str, AgentDefinition] = {}
        for path in sorted(self._config_dir.glob("*.yaml")):
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            definition = AgentDefinition.model_validate(data)
            definition.source_path = path
            definitions[definition.id] = definition
        self._definitions = definitions

    def get(self, agent_id: str) -> AgentDefinition:
        try:
            return self._definitions[agent_id]
        except KeyError as exc:
            available = ", ".join(sorted(self._definitions))
            raise KeyError(f"Unknown agent '{agent_id}'. Available: {available}") from exc

    def list_ids(self) -> list[str]:
        return sorted(self._definitions)
