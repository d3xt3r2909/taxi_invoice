from __future__ import annotations

import re
from pathlib import Path

from tools.ai.model import GeneratedFile, SourceModel
from tools.ai.plugins.base import BasePlugin
from tools.ai.render import render_skill_files


SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class CodexSkillsPlugin(BasePlugin):
    name = "codex-skills"

    def render(self, model: SourceModel) -> list[GeneratedFile]:
        files: list[GeneratedFile] = []
        for skill in model.skills.values():
            if self.config.id in skill.targets and skill.status == "active":
                files.extend(
                    render_skill_files(
                        model,
                        skill,
                        platform=self.config.id,
                        target_dir=Path(".agents") / "skills" / skill.name,
                        include_openai_metadata=True,
                        include_claude_metadata=False,
                    )
                )
        return files

    def validate_source(self, model: SourceModel) -> list[str]:
        errors: list[str] = []
        for skill in model.skills.values():
            if self.config.id not in skill.targets:
                continue
            skill_file = skill.path / "skill.yml"
            if not SKILL_NAME_RE.match(skill.name):
                errors.append(f"error: {skill_file}: skill names must be lowercase hyphenated")
            if not skill.description:
                errors.append(f"error: {skill_file}: Codex-targeted skills need a description")
            if not skill.instructions_path.exists():
                errors.append(f"error: {skill.instructions_path}: referenced skill instructions are missing")
            for reference in skill.reference_paths:
                if not reference.exists():
                    errors.append(f"error: {reference}: referenced skill resource is missing")
            for script in skill.script_paths:
                if not script.exists():
                    errors.append(f"error: {script}: referenced skill script is missing")
                elif script.stat().st_mode & 0o111:
                    errors.append(
                        f"error: {script}: executable skill scripts must be explicitly reviewed "
                        "before being committed as generated resources"
                    )
            openai = skill.metadata.get("openai", {})
            if not isinstance(openai, dict):
                openai = {}
            for key in ("display_name", "short_description", "default_prompt"):
                if not openai.get(key):
                    errors.append(
                        f"error: {skill_file} targets codex-skills but is missing openai.{key}"
                    )
        return errors

    def validate_output(
        self,
        model: SourceModel,
        outputs: list[GeneratedFile],
    ) -> list[str]:
        errors: list[str] = []
        platform_outputs = [output for output in outputs if output.platform == self.config.id]
        for skill in model.skills.values():
            if self.config.id not in skill.targets or skill.status != "active":
                continue
            root = Path(".agents") / "skills" / skill.name
            required = [
                root / "SKILL.md",
                root / "agents" / "openai.yaml",
                root / ".ai-manifest.json",
            ]
            for required_path in required:
                if not any(output.path == required_path for output in platform_outputs):
                    errors.append(f"error: {required_path.as_posix()} must be generated")
        return errors
