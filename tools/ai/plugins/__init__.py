from __future__ import annotations

from tools.ai.plugins.agents import AgentsPlugin
from tools.ai.plugins.claude import ClaudePlugin
from tools.ai.plugins.codex_skills import CodexSkillsPlugin
from tools.ai.plugins.copilot_review import CopilotReviewPlugin
from tools.ai.plugins.cursor import CursorPlugin
from tools.ai.plugins.copilot import CopilotPlugin


PLUGINS = {
    "agents": AgentsPlugin,
    "cursor": CursorPlugin,
    "copilot": CopilotPlugin,
    "copilot-review": CopilotReviewPlugin,
    "claude": ClaudePlugin,
    "codex-skills": CodexSkillsPlugin,
}
