from __future__ import annotations

import json
from pathlib import Path

from tools.ai.core import enabled_platform_ids
from tools.ai.model import GeneratedFile, SourceModel
from tools.ai.plugins import PLUGINS
from tools.ai.plugins.base import BasePlugin
from tools.ai.render import TRACE_TEXT


REQUIRED_FRAGMENT_FIELDS = {"id", "kind", "title", "owner", "status", "targets"}
REQUIRED_SKILL_FIELDS = {"id", "name", "title", "owner", "status", "description", "targets"}
VALID_STATUSES = {"active", "draft", "deprecated"}


def instantiate_plugins(model: SourceModel) -> tuple[dict[str, BasePlugin], list[str]]:
    plugins: dict[str, BasePlugin] = {}
    errors: list[str] = []

    for platform_id in enabled_platform_ids(model):
        config = model.platforms.get(platform_id)
        if config is None:
            errors.append(f"error: ai/config.yml enables unknown platform {platform_id}")
            continue
        plugin_class = PLUGINS.get(config.plugin)
        if plugin_class is None:
            errors.append(
                f"error: {config.path}: platform {platform_id} references unknown plugin {config.plugin}"
            )
            continue
        plugins[platform_id] = plugin_class(config)
    return plugins, errors


def render_all(model: SourceModel, plugins: dict[str, BasePlugin]) -> tuple[list[GeneratedFile], list[str]]:
    errors = collect_source_errors(model, plugins)
    if errors:
        return [], errors

    outputs: list[GeneratedFile] = []
    try:
        for platform_id in enabled_platform_ids(model):
            plugin = plugins.get(platform_id)
            if plugin is not None:
                outputs.extend(plugin.render(model))
    except KeyError as error:
        return [], [f"error: failed to render because source reference is missing: {error}"]

    errors.extend(collect_output_errors(model, plugins, outputs))
    return outputs, errors


def collect_source_errors(model: SourceModel, plugins: dict[str, BasePlugin]) -> list[str]:
    errors = list(model.load_errors)
    enabled = set(enabled_platform_ids(model))

    for platform_id in enabled:
        if platform_id not in model.platforms:
            errors.append(f"error: ai/config.yml enables unknown platform {platform_id}")
        if platform_id not in model.targets:
            errors.append(f"error: enabled platform {platform_id} has no ai/targets/{platform_id}.yml")

    for fragment in model.fragments.values():
        missing = sorted(REQUIRED_FRAGMENT_FIELDS - set(fragment.metadata))
        for field in missing:
            errors.append(f"error: {fragment.path}: fragment is missing frontmatter {field}")
        if fragment.status not in VALID_STATUSES:
            errors.append(f"error: {fragment.path}: unsupported status {fragment.status}")
        if not isinstance(fragment.metadata.get("targets", []), list):
            errors.append(f"error: {fragment.path}: targets must be a list")
        for target in fragment.targets:
            if target not in model.platforms:
                errors.append(f"error: {fragment.path}: targets unknown platform {target}")

    referenced_fragments: set[str] = set()
    for platform, assembly in model.targets.items():
        if platform not in model.platforms:
            errors.append(f"error: {assembly.path}: target references unknown platform {platform}")
        for output in assembly.outputs:
            if not output.id:
                errors.append(f"error: {assembly.path}: output is missing id")
            if not output.path.as_posix() or output.path.as_posix() == ".":
                errors.append(f"error: {assembly.path}: output {output.id} is missing target")
            if output.scope not in model.scopes:
                errors.append(
                    f"error: {assembly.path}: output {output.id} references unknown scope {output.scope}"
                )
            for ref in output.include:
                fragment = model.fragments.get(ref.fragment)
                if fragment is None:
                    errors.append(
                        f"error: {assembly.path}: output {output.id} references unknown fragment {ref.fragment}"
                    )
                    continue
                referenced_fragments.add(ref.fragment)
                if (
                    isinstance(fragment.metadata.get("targets", []), list)
                    and output.platform not in fragment.targets
                ):
                    errors.append(
                        f"error: {assembly.path}: output {output.id} includes fragment "
                        f"{ref.fragment} whose targets omit {output.platform}"
                    )
                if ref.variant not in fragment.variants:
                    errors.append(
                        f"error: {assembly.path}: output {output.id} references unknown variant "
                        f"{ref.variant} for fragment {ref.fragment}"
                    )
                if fragment.status == "draft" and not output.allow_draft:
                    errors.append(
                        f"error: {assembly.path}: output {output.id} renders draft fragment "
                        f"{ref.fragment} without allow_draft: true"
                    )

    for fragment in model.fragments.values():
        if fragment.status == "active" and fragment.id not in referenced_fragments:
            errors.append(f"error: {fragment.path}: active fragment is unreachable from all targets")

    for skill in model.skills.values():
        missing = sorted(REQUIRED_SKILL_FIELDS - set(skill.metadata))
        for field in missing:
            errors.append(f"error: {skill.path / 'skill.yml'}: skill is missing field {field}")
        if skill.status not in VALID_STATUSES:
            errors.append(f"error: {skill.path / 'skill.yml'}: unsupported status {skill.status}")
        if not isinstance(skill.metadata.get("targets", []), list):
            errors.append(f"error: {skill.path / 'skill.yml'}: targets must be a list")
        for target in skill.targets:
            if target not in model.platforms:
                errors.append(f"error: {skill.path / 'skill.yml'}: targets unknown platform {target}")

    for plugin in plugins.values():
        errors.extend(plugin.validate_source(model))

    return errors


def collect_output_errors(
    model: SourceModel,
    plugins: dict[str, BasePlugin],
    outputs: list[GeneratedFile],
) -> list[str]:
    errors: list[str] = []
    seen: dict[Path, GeneratedFile] = {}
    for output in outputs:
        if output.path in seen:
            errors.append(
                f"error: generated path {output.path.as_posix()} is produced by both "
                f"{seen[output.path].platform} and {output.platform}"
            )
        seen[output.path] = output
        if _escapes_repo(output.path):
            errors.append(f"error: generated output {output.path.as_posix()} escapes the repository")

    for plugin in plugins.values():
        errors.extend(plugin.validate_output(model, outputs))
    return errors


def collect_ownership_errors(model: SourceModel, outputs: list[GeneratedFile]) -> list[str]:
    errors: list[str] = []
    expected_by_path = {output.path: output for output in outputs}

    for output in outputs:
        actual_path = model.repo_root / output.path
        if not actual_path.exists():
            errors.append(f"error: {output.path.as_posix()} generated target is missing")
            continue
        actual_content = actual_path.read_text()
        if actual_content != output.content:
            errors.append(f"error: {output.path.as_posix()} was manually edited or is stale")
        if output.path.name == ".ai-manifest.json":
            try:
                manifest = json.loads(actual_content)
            except json.JSONDecodeError:
                errors.append(f"error: {output.path.as_posix()} is not valid JSON")
                continue
            if manifest.get("generated_by") != "scripts/ai":
                errors.append(f"error: {output.path.as_posix()} lacks generated_by manifest metadata")
        elif TRACE_TEXT not in actual_content:
            errors.append(f"error: {output.path.as_posix()} lacks a trace header")

    for platform in model.platforms.values():
        for owned_file in platform.owned_exact_files:
            actual_file = model.repo_root / owned_file
            if actual_file.exists() and owned_file not in expected_by_path:
                errors.append(
                    f"error: {owned_file.as_posix()} is owned by {platform.id} but no target generates it"
                )
        for owned_dir in platform.owned_exact_dirs:
            actual_dir = model.repo_root / owned_dir
            if not actual_dir.exists():
                continue
            for path in sorted(item for item in actual_dir.rglob("*") if item.is_file()):
                relative = path.relative_to(model.repo_root)
                if relative not in expected_by_path:
                    errors.append(
                        f"error: {relative.as_posix()} is inside an owned generated directory "
                        "but no target generates it"
                    )
    return errors


def collect_drift(model: SourceModel, outputs: list[GeneratedFile]) -> tuple[list[str], list[str]]:
    stale: list[str] = []
    extra: list[str] = []
    expected_by_path = {output.path: output for output in outputs}

    for output in outputs:
        actual_path = model.repo_root / output.path
        if not actual_path.exists() or actual_path.read_text() != output.content:
            stale.append(output.path.as_posix())

    for platform in model.platforms.values():
        for owned_dir in platform.owned_exact_dirs:
            actual_dir = model.repo_root / owned_dir
            if not actual_dir.exists():
                continue
            for path in sorted(item for item in actual_dir.rglob("*") if item.is_file()):
                relative = path.relative_to(model.repo_root)
                if relative not in expected_by_path:
                    extra.append(relative.as_posix())
        for owned_file in platform.owned_exact_files:
            actual_file = model.repo_root / owned_file
            if actual_file.exists() and owned_file not in expected_by_path:
                extra.append(owned_file.as_posix())

    return sorted(stale), sorted(extra)


def output_for_path(outputs: list[GeneratedFile], target: Path) -> GeneratedFile | None:
    for output in outputs:
        if output.path == target:
            return output
    for output in outputs:
        try:
            target.relative_to(output.logical_target)
            return output
        except ValueError:
            continue
    return None


def output_inventory(outputs: list[GeneratedFile]) -> dict[str, dict[Path, GeneratedFile]]:
    inventory: dict[str, dict[Path, GeneratedFile]] = {}
    for output in outputs:
        inventory.setdefault(output.platform, {})
        inventory[output.platform].setdefault(output.logical_target, output)
    return inventory


def _escapes_repo(path: Path) -> bool:
    return path.is_absolute() or ".." in path.parts
