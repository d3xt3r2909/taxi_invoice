from __future__ import annotations

import re
from pathlib import Path

from tools.ai.model import GeneratedFile, SourceModel
from tools.ai.plugins.base import BasePlugin
from tools.ai.render import render_markdown_output, render_skill_files


SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class CursorPlugin(BasePlugin):
    name = "cursor"

    def render(self, model: SourceModel) -> list[GeneratedFile]:
        files: list[GeneratedFile] = []
        assembly = model.targets.get(self.config.id)
        if assembly is not None:
            files.extend(
                render_markdown_output(
                    model,
                    output,
                    platform=self.config.id,
                    frontmatter=output.frontmatter,
                )
                for output in assembly.outputs
            )
        for skill in model.skills.values():
            if self.config.id in skill.targets and skill.status == "active":
                files.extend(
                    render_skill_files(
                        model,
                        skill,
                        platform=self.config.id,
                        target_dir=Path(".cursor") / "skills" / skill.name,
                        include_openai_metadata=False,
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
                errors.append(
                    f"error: {skill_file}: Cursor skill names must be lowercase hyphenated"
                )
            if not skill.description:
                errors.append(f"error: {skill_file}: Cursor-targeted skills need a description")
            if not skill.instructions_path.exists():
                errors.append(
                    f"error: {skill.instructions_path}: referenced skill instructions are missing"
                )
            for reference in skill.reference_paths:
                if not reference.exists():
                    errors.append(f"error: {reference}: referenced skill resource is missing")
            for script in skill.script_paths:
                if not script.exists():
                    errors.append(f"error: {script}: referenced skill script is missing")
        return errors

    def validate_output(
        self,
        model: SourceModel,
        outputs: list[GeneratedFile],
    ) -> list[str]:
        errors: list[str] = []
        required = self.config.requirements.get("required_frontmatter", [])
        extension = str(self.config.requirements.get("extension", ".mdc"))
        rules_root = ".cursor/rules/ai/"
        skills_root = ".cursor/skills/"

        assembly = model.targets.get(self.config.id)
        frontmatter_by_path = {
            output.path.as_posix(): output.frontmatter for output in assembly.outputs
        } if assembly else {}

        for output in outputs:
            if output.platform != self.config.id:
                continue
            path = output.path.as_posix()
            if path.startswith(skills_root):
                continue
            if not path.endswith(extension):
                errors.append(f"error: {path} must end with {extension}")
            if not path.startswith(rules_root):
                errors.append(f"error: {path} must be inside .cursor/rules/ai")
            frontmatter = frontmatter_by_path.get(path, {})
            for key in required:
                if key not in frontmatter:
                    errors.append(f"error: {path} is missing Cursor frontmatter {key}")
            always_apply = frontmatter.get("alwaysApply") is True
            max_chars = int(self.config.limits.get("always_on_max_chars") or 0)
            if always_apply and max_chars and len(output.content) > max_chars:
                errors.append(
                    f"error: {path} would be {len(output.content)} chars, limit is {max_chars}"
                )

        platform_outputs = [output for output in outputs if output.platform == self.config.id]
        for skill in model.skills.values():
            if self.config.id not in skill.targets or skill.status != "active":
                continue
            root = Path(".cursor") / "skills" / skill.name
            required_paths = [
                root / "SKILL.md",
                root / ".ai-manifest.json",
            ]
            for required_path in required_paths:
                if not any(output.path == required_path for output in platform_outputs):
                    errors.append(f"error: {required_path.as_posix()} must be generated")
        return errors
