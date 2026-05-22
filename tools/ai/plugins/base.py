from __future__ import annotations

from pathlib import Path

from tools.ai.model import GeneratedFile, PlatformConfig, SourceModel


class BasePlugin:
    name = "base"

    def __init__(self, config: PlatformConfig) -> None:
        self.config = config

    def owned_paths(self, model: SourceModel) -> list[Path]:
        return [*self.config.owned_exact_files, *self.config.owned_exact_dirs]

    def validate_source(self, model: SourceModel) -> list[str]:
        return []

    def render(self, model: SourceModel) -> list[GeneratedFile]:
        return []

    def validate_output(
        self,
        model: SourceModel,
        outputs: list[GeneratedFile],
    ) -> list[str]:
        return []

    def explain(self, model: SourceModel, target: Path) -> str | None:
        return None
