from __future__ import annotations

from tools.ai.model import GeneratedFile, SourceModel
from tools.ai.plugins.base import BasePlugin
from tools.ai.render import render_markdown_output


class AgentsPlugin(BasePlugin):
    name = "agents"

    def render(self, model: SourceModel) -> list[GeneratedFile]:
        assembly = model.targets.get(self.config.id)
        if assembly is None:
            return []
        return [
            render_markdown_output(model, output, platform=self.config.id)
            for output in assembly.outputs
        ]

    def validate_output(
        self,
        model: SourceModel,
        outputs: list[GeneratedFile],
    ) -> list[str]:
        errors: list[str] = []
        platform_outputs = [output for output in outputs if output.platform == self.config.id]
        if not any(output.path.as_posix() == "AGENTS.md" for output in platform_outputs):
            errors.append("error: agents platform must generate root AGENTS.md")

        for output in platform_outputs:
            if output.path.name == "AGENTS.md" and output.path.parent.as_posix() != ".":
                errors.append("error: MVP must not generate nested AGENTS.md files")
            max_chars = int(output.limits.get("max_chars") or self.config.limits.get("max_chars_per_file") or 0)
            if max_chars and len(output.content) > max_chars:
                errors.append(
                    f"error: {output.path.as_posix()} would be {len(output.content)} chars, "
                    f"limit is {max_chars}"
                )
        return errors
