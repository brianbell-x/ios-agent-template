from __future__ import annotations

import hashlib
from pathlib import Path

import yaml

from app.agents.definitions import AgentDefinition


class AgentCatalog:
    def __init__(self, config_dir: Path):
        self._config_dir = config_dir
        self._definitions: dict[str, AgentDefinition] = {}
        self._version = ""
        self.reload()

    @property
    def config_dir(self) -> Path:
        return self._config_dir

    def reload(self) -> None:
        definitions: dict[str, AgentDefinition] = {}
        digest = hashlib.sha256()
        for path in sorted(self._config_dir.glob("*.yaml")):
            contents = path.read_text(encoding="utf-8")
            data = yaml.safe_load(contents) or {}
            definition = AgentDefinition.model_validate(data)
            definition.source_path = path
            if definition.id in definitions:
                raise ValueError(f"Duplicate agent id '{definition.id}' in {path.name}")
            definitions[definition.id] = definition
            digest.update(path.name.encode("utf-8"))
            digest.update(contents.encode("utf-8"))
        self._definitions = definitions
        self._version = digest.hexdigest()

    def get(self, agent_id: str) -> AgentDefinition:
        try:
            return self._definitions[agent_id]
        except KeyError as exc:
            available = ", ".join(sorted(self._definitions))
            raise KeyError(f"Unknown agent '{agent_id}'. Available: {available}") from exc

    def list_ids(self) -> list[str]:
        return sorted(self._definitions)

    def definitions(self) -> list[AgentDefinition]:
        return [self._definitions[agent_id] for agent_id in self.list_ids()]

    @property
    def version(self) -> str:
        return self._version
