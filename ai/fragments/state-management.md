---
id: state-management
kind: instruction
title: State management and screen structure
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

State is currently managed with Flutter controllers and `ChangeNotifier`-style app/store controllers.

Keep mutable app state inside dedicated controller or repository classes, not scattered through UI widgets. UI screens should trigger controller operations and render current values, while persistence and data normalization stay in `store` or `settings`.

When adding asynchronous work, expose loading/error states explicitly enough for the UI to show a useful state. Keep generated PDF state derived from invoice models rather than duplicating document data in widgets.

Avoid introducing BLoC, Riverpod, Provider, or another state-management framework unless a concrete feature needs it and the migration is intentional.

# Compressed

Use existing controller/repository state patterns. Keep mutable state in `store` or `settings`, keep UI focused on rendering and user actions, and keep PDF output derived from invoice models. Do not add a new state-management framework without a clear need.
