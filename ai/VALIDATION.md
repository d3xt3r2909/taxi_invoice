# Validation

`scripts/ai validate` checks source metadata, platform constraints, generated ownership, and drift.

Common failures:

- Missing fragment frontmatter such as `id`, `kind`, `title`, `owner`, `status`, or `targets`.
- Duplicate fragment or skill ids.
- Target references an unknown fragment, variant, scope, or platform.
- Active fragment is unreachable from every target.
- Draft content is rendered without `allow_draft: true`.
- Enabled platform has no compiler plugin.
- Generated file is missing, stale, or lacks a trace header.
- Owned generated directory contains an unregistered file.
- Copilot review output exceeds 3,900 characters.
- Codex skill targets miss required OpenAI metadata.
- Cursor-targeted skills miss required `name`, `description`, or generated `SKILL.md`.

Fix source files under `ai/**`, then run `scripts/ai generate`.
