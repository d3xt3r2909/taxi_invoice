# Examples

Add a review rule:

1. Edit `ai/fragments/review.md`.
2. Update both `# Standard` and `# Compressed` if the rule is used by limited-context targets.
3. Run `scripts/ai generate --check`; if it fails, run `scripts/ai generate`.

Add a compressed variant:

1. Add `compressed: true` under `variants`.
2. Add a `# Compressed` heading.
3. Reference the variant from a target with `variant: compressed`.

Add a new skill:

1. Create `ai/skills/<name>/skill.yml`.
2. Add `instructions.md` and optional references.
3. Include the desired platform targets.
4. Add owned generated directories in the platform configs.

Add a Cursor scoped rule:

1. Add or reuse a scope in `ai/scopes.yml`.
2. Add an output in `ai/targets/cursor.yml`.
3. Include `description` and `alwaysApply` frontmatter.

Enable a skill for Cursor:

1. Add `cursor` to the skill's `targets` in `ai/skills/<name>/skill.yml`.
2. Run `scripts/ai generate`.
3. Verify `.cursor/skills/<name>/SKILL.md` and `.cursor/skills/<name>/.ai-manifest.json` were generated.

Add a new platform plugin:

1. Add `ai/platforms/<platform>.yml`.
2. Add `ai/targets/<platform>.yml`.
3. Implement `tools/ai/plugins/<platform>.py`.
4. Register the plugin in `tools/ai/plugins/__init__.py`.
