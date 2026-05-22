# Platforms

Supported MVP platforms and their generated placements:

| Platform | Generated placement | Enablement notes |
| --- | --- | --- |
| `agents` | `AGENTS.md` at the repository root | Codex reads project instructions from the project root down to the current directory. GitHub Copilot agents and Cursor also understand `AGENTS.md`, so this is the shared baseline. |
| `cursor` | `.cursor/rules/ai/*.mdc` and `.cursor/skills/<skill>/SKILL.md` | Cursor project rules are versioned files under `.cursor/rules`. Cursor Agent Skills are project skills under `.cursor/skills`; the generator emits this explicit copy instead of relying on cross-tool discovery from `.agents/skills`. |
| `copilot` | `.github/copilot-instructions.md` | Repository-wide Copilot instructions. Copilot adds them automatically when repository instructions are enabled for the product surface. |
| `copilot-review` | `.github/instructions/ai-review/*.instructions.md` | Path-specific Copilot instructions require `applyTo`. Review-only files must set `excludeAgent: "cloud-agent"` so edit sessions do not receive review guidance. |
| `claude` | `CLAUDE.md` and `.claude/skills/pr-review` | Claude Code project memory lives at root `CLAUDE.md`; project skills live under `.claude/skills/<skill>/SKILL.md`. |
| `codex-skills` | `.agents/skills/<skill>/SKILL.md`, optional resources, `.ai-manifest.json`, and `agents/openai.yaml` | Codex scans repository skills from `.agents/skills` directories between the current working directory and repository root. `agents/openai.yaml` is optional UI/policy metadata. |

Official references:

- Codex AGENTS.md: https://developers.openai.com/codex/guides/agents-md
- Codex skills: https://developers.openai.com/codex/skills
- Cursor rules: https://docs.cursor.com/context/rules
- Cursor skills: https://cursor.com/docs/skills
- GitHub Copilot repository instructions: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions
- GitHub Copilot instruction support matrix: https://docs.github.com/en/copilot/reference/custom-instructions-support
- GitHub Copilot agent skills: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
- Claude Code memory: https://docs.anthropic.com/en/docs/claude-code/memory
- Claude Code skills: https://code.claude.com/docs/en/skills

Owned paths are declared in `ai/platforms/*.yml`. This repo owns only generated subpaths so existing unmanaged `.agents`, `.cursor`, `.claude`, and `.github` files can continue to exist until migrated.

Deferred features include nested `AGENTS.md`, optional `.github/skills` mirroring for GitHub-specific skill hosting, Codex command rules, and external package publishing.
