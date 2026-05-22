from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Fragment:
    id: str
    path: Path
    metadata: dict[str, Any]
    variants: dict[str, str]

    @property
    def title(self) -> str:
        return str(self.metadata.get("title", self.id))

    @property
    def status(self) -> str:
        return str(self.metadata.get("status", "active"))

    @property
    def targets(self) -> list[str]:
        targets = self.metadata.get("targets", [])
        return list(targets) if isinstance(targets, list) else []


@dataclass(frozen=True)
class Scope:
    id: str
    description: str
    paths: list[str]


@dataclass(frozen=True)
class PlatformConfig:
    id: str
    display_name: str
    plugin: str
    path: Path
    owned_exact_dirs: list[Path]
    owned_exact_files: list[Path]
    limits: dict[str, Any]
    requirements: dict[str, Any]


@dataclass(frozen=True)
class FragmentRef:
    fragment: str
    variant: str


@dataclass(frozen=True)
class TargetOutput:
    id: str
    platform: str
    path: Path
    source_path: Path
    scope: str
    title: str
    frontmatter: dict[str, Any]
    limits: dict[str, Any]
    include: list[FragmentRef]
    include_imports: list[str]
    allow_draft: bool


@dataclass(frozen=True)
class TargetAssembly:
    platform: str
    path: Path
    outputs: list[TargetOutput]


@dataclass(frozen=True)
class Skill:
    id: str
    name: str
    path: Path
    metadata: dict[str, Any]
    instructions_path: Path
    reference_paths: list[Path]
    script_paths: list[Path]

    @property
    def title(self) -> str:
        return str(self.metadata.get("title", self.name))

    @property
    def description(self) -> str:
        return str(self.metadata.get("description", ""))

    @property
    def status(self) -> str:
        return str(self.metadata.get("status", "active"))

    @property
    def targets(self) -> list[str]:
        targets = self.metadata.get("targets", [])
        return list(targets) if isinstance(targets, list) else []


@dataclass(frozen=True)
class SourceModel:
    repo_root: Path
    config: dict[str, Any]
    scopes: dict[str, Scope]
    fragments: dict[str, Fragment]
    platforms: dict[str, PlatformConfig]
    targets: dict[str, TargetAssembly]
    skills: dict[str, Skill]
    load_errors: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class GeneratedFile:
    path: Path
    content: str
    platform: str
    source_ids: tuple[str, ...]
    logical_target: Path
    limits: dict[str, Any] = field(default_factory=dict)
