---
id: build-test
kind: instruction
title: Build and test
owner: platform
status: active
targets:
  - agents
  - cursor
  - copilot
  - claude
variants:
  standard: true
  compressed: true
---

# Standard

Before changing behavior, inspect nearby code and tests. Validate changes with the narrowest useful command first, then broaden only when the touched surface area requires it.

Useful commands:

- `dart format <changed dart files>`
- `flutter analyze`
- `flutter test`
- `flutter test <path>`
- `flutter build web`

Prefer the narrowest useful test run for focused changes. Use broader Flutter checks when work touches PDF generation, persistence, platform save/reveal helpers, import/export, or app-wide settings.

Avoid unnecessary `pubspec.lock` changes. When dependencies are added or changed, run the relevant Flutter command that refreshes lockfile state intentionally.

For widget tests that depend on theme colors or theme extensions, wrap the widget with an explicit `Theme` and assert the widget property or inherited `IconTheme` value directly.

Use simple tests for pass-through values. Use parameterized tests when different inputs produce different behavior, and prefer map-style parameterized cases when checking several input-to-output pairs.

# Compressed

Inspect nearby code and tests before editing. Validate with the narrowest useful command, usually `dart format <changed dart files>`, `flutter analyze`, `flutter test <path>`, or `flutter test`. Broaden checks for PDF generation, persistence, platform helpers, import/export, or settings changes.
