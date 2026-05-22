---
id: repo
kind: instruction
title: Project overview
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

App Taxi Invoice is a standalone Flutter app for creating, storing, importing, exporting, and printing taxi invoice PDFs.

Primary stack:

- Flutter and Dart SDK `^3.10.0`
- `pdf` and `printing` for document generation and preview/print/share flows
- `shared_preferences` and local repositories for persisted invoice data
- `file_picker`, `file_selector`, `path_provider`, `open_file`, and platform-specific helpers for import/export and reveal flows
- `intl` for date and number formatting
- `flutter_lints` for baseline analysis rules

The app is not a monorepo and should not depend on unrelated company-specific mobile app packages. Keep changes local to this package and avoid importing private machine paths, external service assumptions, or unrelated helper libraries.

# Compressed

Standalone Flutter app for taxi invoice PDF creation, persistence, import/export, and printing. Use the local `pubspec.yaml`, keep changes scoped to this package, and avoid unrelated app-specific dependencies or local machine assumptions.
