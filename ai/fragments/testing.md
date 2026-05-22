---
id: testing
kind: instruction
title: Testing patterns
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

Use tests to verify observable behavior, not implementation details. Prefer one behavior and one primary expectation per test unless multiple expectations describe closely related properties of a single entity.

Use Arrange, Act, Assert as the mental model. When all three sections are present, separate them with exactly two blank separator lines: one between Arrange and Act, and one between Act and Assert. Do not add comments named `Arrange`, `Act`, or `Assert`.

Use simple tests for pass-through values. Parameterize only when different inputs produce different behavior. Prefer map-style parameterized tests with `.forEach` for input-to-output cases.

For widget tests, use small local pump helpers or `WidgetTester` extensions with sensible defaults. Keep helper defaults for irrelevant values and pass explicit values only when they matter to the behavior under test.

For widget tests that depend on theme colors or theme extensions, wrap the widget with an explicit `Theme`, then assert the public widget property or inherited `IconTheme` value directly.

Use private `_ArrangeBuilder` helpers when tests need repeated setup for repositories, controllers, files, or platform fakes.

For PDF behavior, prefer tests that inspect generated model/output properties or text presence rather than brittle byte-for-byte PDF snapshots.

# Compressed

Test observable behavior with focused expectations. Use AAA as the mental model with exactly two blank separator lines when Arrange, Act, and Assert are all present. Do not parameterize simple pass-through wiring; use map-style parameterized tests for behavior differences. Use local pump helpers and `_ArrangeBuilder` according to the tested surface.
