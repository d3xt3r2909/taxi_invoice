from __future__ import annotations

from tools.ai.model import GeneratedFile, SourceModel
from tools.ai.plugins.base import BasePlugin
from tools.ai.render import render_markdown_output


class CopilotPlugin(BasePlugin):
    name = "copilot"

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
        if not any(
            output.path.as_posix() == ".github/copilot-instructions.md"
            for output in platform_outputs
        ):
            errors.append("error: copilot platform must generate .github/copilot-instructions.md")
        for output in platform_outputs:
            if output.path.as_posix() != ".github/copilot-instructions.md":
                errors.append(
                    f"error: {output.path.as_posix()} must be .github/copilot-instructions.md"
                )
        return errors
