---
id: navigation-localization
kind: instruction
title: Navigation and localization
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

Use the app's existing Flutter navigation style. For simple screen transitions, prefer standard Flutter APIs (`Navigator`, `MaterialPageRoute`, dialogs, and sheets) consistent with nearby UI code.

The app currently keeps user-facing strings inline. If localization becomes necessary, use Flutter's standard localization tooling and keep formatting locale-aware through `intl`.

For invoice dates, currency-like values, and PDF text, prefer explicit formatting helpers so UI and PDF output remain consistent.

# Compressed

Use the existing Flutter navigation style. Inline strings are acceptable for now; use `intl` and local formatting helpers for dates, amounts, and PDF text so UI and generated invoices stay consistent.
