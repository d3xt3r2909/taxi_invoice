# Create AI Instructions

Use CREATE (Classify, Register, Express, Assemble, Test, Evaluate):

- Classify: choose fragment, scope, target, skill, platform, policy, or template.
- Register: add metadata such as `id`, `owner`, `status`, and `targets`.
- Express: write the content once under `ai/**`.
- Assemble: reference it from `ai/targets/*.yml`.
- Test: run `scripts/ai validate`, `scripts/ai generate`, and `scripts/ai generate --check`.
- Evaluate: update validation, platform docs, and tests when the source model changes.

Fragments live in `ai/fragments/*.md` with YAML frontmatter and human-authored variants such as `# Standard` and `# Compressed`.

Skills live in `ai/skills/<name>/` with `skill.yml`, `instructions.md`, and optional references. Platform plugins generate native `SKILL.md` files from the same source.

Platforms require `ai/platforms/<platform>.yml`, `ai/targets/<platform>.yml`, and a plugin under `tools/ai/plugins/`.
