from __future__ import annotations

from pathlib import Path

from tools.ai.model import GeneratedFile, SourceModel
from tools.ai.plugins.base import BasePlugin
from tools.ai.render import render_markdown_output, render_skill_files


class ClaudePlugin(BasePlugin):
    name = "claude"

    def render(self, model: SourceModel) -> list[GeneratedFile]:
        files: list[GeneratedFile] = []
        assembly = model.targets.get(self.config.id)
        if assembly is not None:
            files.extend(
                render_markdown_output(
                    model,
                    output,
                    platform=self.config.id,
                    imports=output.include_imports,
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
                        target_dir=Path(".claude") / "skills" / skill.name,
                        include_openai_metadata=False,
                        include_claude_metadata=True,
                    )
                )
        return files

    def validate_source(self, model: SourceModel) -> list[str]:
        errors: list[str] = []
        for skill in model.skills.values():
            if self.config.id not in skill.targets:
                continue
            if not skill.description:
                errors.append(f"error: {skill.path / 'skill.yml'}: Claude-targeted skills need a description")
            if not skill.instructions_path.exists():
                errors.append(f"error: {skill.instructions_path}: referenced skill instructions are missing")
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
        platform_outputs = [output for output in outputs if output.platform == self.config.id]
        claude_memory = next(
            (output for output in platform_outputs if output.path.as_posix() == "CLAUDE.md"),
            None,
        )
        if claude_memory is None:
            errors.append("error: claude platform must generate CLAUDE.md")
        elif "@AGENTS.md" not in claude_memory.content and "AGENTS.md" not in claude_memory.content:
            errors.append("error: CLAUDE.md must import AGENTS.md or include shared content")

        for skill in model.skills.values():
            if self.config.id not in skill.targets or skill.status != "active":
                continue
            skill_file = Path(".claude") / "skills" / skill.name / "SKILL.md"
            if not any(output.path == skill_file for output in platform_outputs):
                errors.append(f"error: {skill_file.as_posix()} must be generated")
        return errors
