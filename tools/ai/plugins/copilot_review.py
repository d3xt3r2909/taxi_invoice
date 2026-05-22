from __future__ import annotations

from tools.ai.model import GeneratedFile, SourceModel
from tools.ai.plugins.base import BasePlugin
from tools.ai.render import render_markdown_output


class CopilotReviewPlugin(BasePlugin):
    name = "copilot-review"

    def validate_source(self, model: SourceModel) -> list[str]:
        errors: list[str] = []
        assembly = model.targets.get(self.config.id)
        if assembly is None:
            return errors
        for output in assembly.outputs:
            for item in output.include:
                if item.variant != "compressed":
                    errors.append(
                        f"error: {output.source_path}: {output.id} must use compressed variants "
                        "for copilot-review"
                    )
        return errors

    def render(self, model: SourceModel) -> list[GeneratedFile]:
        assembly = model.targets.get(self.config.id)
        if assembly is None:
            return []
        return [
            render_markdown_output(
                model,
                output,
                platform=self.config.id,
                frontmatter=output.frontmatter,
            )
            for output in assembly.outputs
        ]

    def validate_output(
        self,
        model: SourceModel,
        outputs: list[GeneratedFile],
    ) -> list[str]:
        errors: list[str] = []
        required = self.config.requirements.get("required_frontmatter", [])
        extension = str(self.config.requirements.get("extension", ".instructions.md"))
        owned_root = ".github/instructions/ai-review/"
        assembly = model.targets.get(self.config.id)
        frontmatter_by_path = {
            output.path.as_posix(): output.frontmatter for output in assembly.outputs
        } if assembly else {}
        limit_by_path = {
            output.path.as_posix(): output.limits for output in assembly.outputs
        } if assembly else {}

        for output in outputs:
            if output.platform != self.config.id:
                continue
            path = output.path.as_posix()
            if not path.endswith(extension):
                errors.append(f"error: {path} must end with {extension}")
            if not path.startswith(owned_root):
                errors.append(f"error: {path} must be inside .github/instructions/ai-review")
            frontmatter = frontmatter_by_path.get(path, {})
            for key in required:
                if key not in frontmatter:
                    errors.append(f"error: {path} is missing Copilot frontmatter {key}")
            if frontmatter.get("excludeAgent") != "cloud-agent":
                errors.append(
                    f"error: {path} must set excludeAgent: cloud-agent "
                    "so review guidance is not attached to Copilot cloud-agent tasks"
                )
            max_chars = int(
                limit_by_path.get(path, {}).get("max_chars")
                or self.config.limits.get("max_chars_per_file")
                or 0
            )
            if max_chars and len(output.content) > max_chars:
                errors.append(
                    f"error: {path} would be {len(output.content)} chars, limit is {max_chars}"
                )
        return errors
