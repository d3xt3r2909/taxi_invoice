from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from tools.ai.model import (
    Fragment,
    FragmentRef,
    PlatformConfig,
    Scope,
    Skill,
    SourceModel,
    TargetAssembly,
    TargetOutput,
)
from tools.ai.yaml_util import YamlError, load_yaml, parse_yaml


FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n?(.*)\Z", re.DOTALL)
HEADING_RE = re.compile(r"^#\s+(.+?)\s*$")


def load_model(repo_root: Path) -> SourceModel:
    repo_root = repo_root.resolve()
    ai_root = repo_root / "ai"
    errors: list[str] = []

    config = _load_yaml_file(ai_root / "config.yml", errors)
    scopes = _load_scopes(ai_root / "scopes.yml", errors)
    fragments = _load_fragments(ai_root / "fragments", errors)
    platforms = _load_platforms(ai_root / "platforms", errors)
    targets = _load_targets(ai_root / "targets", errors)
    skills = _load_skills(ai_root / "skills", errors)

    return SourceModel(
        repo_root=repo_root,
        config=config if isinstance(config, dict) else {},
        scopes=scopes,
        fragments=fragments,
        platforms=platforms,
        targets=targets,
        skills=skills,
        load_errors=errors,
    )


def repo_relative(repo_root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def normalize_repo_path(path: str | Path) -> Path:
    return Path(str(path).replace("\\", "/"))


def _optional_string_list(
    value: Any,
    *,
    path: Path,
    field: str,
    errors: list[str],
) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        errors.append(f"error: {path}: {field} must be a list")
        return []
    return [str(item) for item in value]


def enabled_platform_ids(model: SourceModel) -> list[str]:
    enabled = model.config.get("enabled_platforms", [])
    return [str(platform) for platform in enabled] if isinstance(enabled, list) else []


def parse_markdown_frontmatter(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text()
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}, text
    metadata_text, body = match.groups()
    metadata = parse_yaml(metadata_text, source=str(path))
    if not isinstance(metadata, dict):
        metadata = {}
    return metadata, body


def fragment_sources(model: SourceModel, output: TargetOutput) -> tuple[str, ...]:
    sources = [repo_relative(model.repo_root, output.source_path)]
    for ref in output.include:
        fragment = model.fragments.get(ref.fragment)
        if fragment is not None:
            sources.append(f"{repo_relative(model.repo_root, fragment.path)}#{ref.variant}")
    return tuple(sources)


def render_included_fragments(model: SourceModel, output: TargetOutput) -> str:
    parts: list[str] = []
    for ref in output.include:
        fragment = model.fragments[ref.fragment]
        content = fragment.variants[ref.variant].strip()
        parts.append(f"## {fragment.title}\n\n{content}")
    return "\n\n".join(parts).rstrip() + "\n"


def _load_yaml_file(path: Path, errors: list[str]) -> Any:
    try:
        return load_yaml(path)
    except FileNotFoundError:
        errors.append(f"error: {path}: file is missing")
    except YamlError as error:
        errors.append(f"error: {error}")
    return {}


def _load_scopes(path: Path, errors: list[str]) -> dict[str, Scope]:
    data = _load_yaml_file(path, errors)
    raw_scopes = data.get("scopes", {}) if isinstance(data, dict) else {}
    scopes: dict[str, Scope] = {}
    if not isinstance(raw_scopes, dict):
        errors.append(f"error: {path}: scopes must be a mapping")
        return scopes

    for scope_id, raw_scope in raw_scopes.items():
        if not isinstance(raw_scope, dict):
            errors.append(f"error: {path}: scope {scope_id} must be a mapping")
            continue
        paths = raw_scope.get("paths", [])
        scopes[str(scope_id)] = Scope(
            id=str(scope_id),
            description=str(raw_scope.get("description", "")),
            paths=[str(item) for item in paths] if isinstance(paths, list) else [],
        )
    return scopes


def _load_fragments(root: Path, errors: list[str]) -> dict[str, Fragment]:
    fragments: dict[str, Fragment] = {}
    if not root.exists():
        errors.append(f"error: {root}: directory is missing")
        return fragments

    for path in sorted(root.glob("*.md")):
        try:
            metadata, body = parse_markdown_frontmatter(path)
        except YamlError as error:
            errors.append(f"error: {error}")
            continue

        fragment_id = str(metadata.get("id") or path.stem)
        if fragment_id in fragments:
            errors.append(
                "error: "
                f"{path}: duplicate fragment id {fragment_id} also used by {fragments[fragment_id].path}"
            )
            continue

        fragments[fragment_id] = Fragment(
            id=fragment_id,
            path=path,
            metadata=metadata,
            variants=_extract_variants(path, metadata, body, errors),
        )
    return fragments


def _extract_variants(
    path: Path,
    metadata: dict[str, Any],
    body: str,
    errors: list[str],
) -> dict[str, str]:
    declared = metadata.get("variants", {})
    if isinstance(declared, dict):
        declared_names = [str(name) for name, enabled in declared.items() if enabled]
    else:
        declared_names = []

    sections: dict[str, list[str]] = {}
    current_name: str | None = None
    for line in body.splitlines():
        match = HEADING_RE.match(line)
        if match:
            current_name = _variant_name(match.group(1))
            sections[current_name] = []
            continue
        if current_name is not None:
            sections[current_name].append(line)

    if not sections and "standard" in declared_names:
        return {"standard": body.strip() + "\n"}

    variants: dict[str, str] = {}
    for name in declared_names:
        if name not in sections:
            errors.append(f"error: {path}: declared variant {name} has no matching heading")
            continue
        variants[name] = "\n".join(sections[name]).strip() + "\n"
    return variants


def _variant_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")


def _load_platforms(root: Path, errors: list[str]) -> dict[str, PlatformConfig]:
    platforms: dict[str, PlatformConfig] = {}
    if not root.exists():
        errors.append(f"error: {root}: directory is missing")
        return platforms

    for path in sorted(root.glob("*.yml")):
        data = _load_yaml_file(path, errors)
        if not isinstance(data, dict):
            errors.append(f"error: {path}: platform config must be a mapping")
            continue
        platform_id = str(data.get("id") or path.stem)
        owned = data.get("owned", {})
        if not isinstance(owned, dict):
            owned = {}
        exact_dirs = _optional_string_list(
            owned.get("exact_dirs"),
            path=path,
            field="owned.exact_dirs",
            errors=errors,
        )
        exact_files = _optional_string_list(
            owned.get("exact_files"),
            path=path,
            field="owned.exact_files",
            errors=errors,
        )
        platforms[platform_id] = PlatformConfig(
            id=platform_id,
            display_name=str(data.get("display_name") or platform_id),
            plugin=str(data.get("plugin") or platform_id),
            path=path,
            owned_exact_dirs=[normalize_repo_path(item) for item in exact_dirs],
            owned_exact_files=[normalize_repo_path(item) for item in exact_files],
            limits=data.get("limits", {}) if isinstance(data.get("limits", {}), dict) else {},
            requirements=(
                data.get("requirements", {})
                if isinstance(data.get("requirements", {}), dict)
                else {}
            ),
        )
    return platforms


def _load_targets(root: Path, errors: list[str]) -> dict[str, TargetAssembly]:
    assemblies: dict[str, TargetAssembly] = {}
    if not root.exists():
        errors.append(f"error: {root}: directory is missing")
        return assemblies

    for path in sorted(root.glob("*.yml")):
        data = _load_yaml_file(path, errors)
        if not isinstance(data, dict):
            errors.append(f"error: {path}: target assembly must be a mapping")
            continue
        platform = path.stem
        raw_outputs = data.get("outputs", [])
        if not isinstance(raw_outputs, list):
            errors.append(f"error: {path}: outputs must be a list")
            raw_outputs = []

        outputs: list[TargetOutput] = []
        for raw_output in raw_outputs:
            if not isinstance(raw_output, dict):
                errors.append(f"error: {path}: each output must be a mapping")
                continue
            raw_include = raw_output.get("include", [])
            include: list[FragmentRef] = []
            if isinstance(raw_include, list):
                for raw_ref in raw_include:
                    if not isinstance(raw_ref, dict):
                        errors.append(f"error: {path}: include entries must be mappings")
                        continue
                    include.append(
                        FragmentRef(
                            fragment=str(raw_ref.get("fragment", "")),
                            variant=str(raw_ref.get("variant", "standard")),
                        )
                    )

            include_imports = raw_output.get("include_imports", [])
            outputs.append(
                TargetOutput(
                    id=str(raw_output.get("id") or ""),
                    platform=platform,
                    path=normalize_repo_path(str(raw_output.get("target", ""))),
                    source_path=path,
                    scope=str(raw_output.get("scope", "root")),
                    title=str(raw_output.get("title") or raw_output.get("id") or ""),
                    frontmatter=(
                        raw_output.get("frontmatter", {})
                        if isinstance(raw_output.get("frontmatter", {}), dict)
                        else {}
                    ),
                    limits=(
                        raw_output.get("limits", {})
                        if isinstance(raw_output.get("limits", {}), dict)
                        else {}
                    ),
                    include=include,
                    include_imports=(
                        [str(item) for item in include_imports]
                        if isinstance(include_imports, list)
                        else []
                    ),
                    allow_draft=bool(raw_output.get("allow_draft", False)),
                )
            )
        assemblies[platform] = TargetAssembly(platform=platform, path=path, outputs=outputs)
    return assemblies


def _load_skills(root: Path, errors: list[str]) -> dict[str, Skill]:
    skills: dict[str, Skill] = {}
    if not root.exists():
        return skills

    for skill_dir in sorted(path for path in root.iterdir() if path.is_dir()):
        skill_file = skill_dir / "skill.yml"
        data = _load_yaml_file(skill_file, errors)
        if not isinstance(data, dict):
            errors.append(f"error: {skill_file}: skill metadata must be a mapping")
            continue
        skill_id = str(data.get("id") or skill_dir.name)
        if skill_id in skills:
            errors.append(
                "error: "
                f"{skill_file}: duplicate skill id {skill_id} also used by {skills[skill_id].path}"
            )
            continue

        source = data.get("source", {})
        if not isinstance(source, dict):
            source = {}
        resources = data.get("resources", {})
        if not isinstance(resources, dict):
            resources = {}
        references = _optional_string_list(
            resources.get("references"),
            path=skill_file,
            field="resources.references",
            errors=errors,
        )
        scripts = _optional_string_list(
            resources.get("scripts"),
            path=skill_file,
            field="resources.scripts",
            errors=errors,
        )
        skills[skill_id] = Skill(
            id=skill_id,
            name=str(data.get("name") or skill_id),
            path=skill_dir,
            metadata=data,
            instructions_path=skill_dir
            / normalize_repo_path(str(source.get("instructions", "instructions.md"))),
            reference_paths=[skill_dir / normalize_repo_path(item) for item in references],
            script_paths=[skill_dir / normalize_repo_path(item) for item in scripts],
        )
    return skills
