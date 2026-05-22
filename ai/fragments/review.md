---
id: review
kind: instruction
title: Review checklist
owner: platform
status: active
targets:
  - agents
  - cursor
  - copilot
  - copilot-review
  - claude
variants:
  standard: true
  compressed: true
---

# Standard

When reviewing code, prioritize correctness, security, tests, maintainability, user-facing behavior, and backward compatibility.

Prefer specific comments that name the risk and suggest a concrete fix. Avoid broad style feedback when the code already follows local conventions.

Do not comment on `TODO` markers as a standalone topic. Treat them as intentional placeholders unless they violate repo policy or the author asked for help resolving them.

Do not report code as unused, dead, or unnecessary when a nearby `TODO` or the same change indicates the symbol, import, or block is intended for a planned follow-up.

Tests should usually have one `expect` per test unless checking closely related properties of one entity. Use parameterized tests when different inputs produce different behavior, not for simple pass-through verification.

PRs should avoid unnecessary `pubspec.lock` churn, preserve import/export and PDF-generation flows, avoid leaking invoice data, and pass the relevant local validation command before merge.

# Compressed

Review for correctness, security, tests, maintainability, behavior, and compatibility. Prefer actionable comments with concrete fixes. Do not flag standalone `TODO`s or planned follow-up code as dead. Check invoice/PDF behavior, persistence, platform helpers, lockfile churn, and focused tests.
