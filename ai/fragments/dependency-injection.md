---
id: dependency-injection
kind: instruction
title: Dependency injection
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

This app does not currently use a dependency injection framework.

Prefer explicit constructor parameters for dependencies such as repositories, controllers, formatters, and platform helpers. Keep default wiring near the entry point or the screen that owns the lifecycle.

When a dependency needs disposal or persistence, make ownership clear in the widget/controller that creates it. Avoid adding a service locator or DI package unless the app has enough repeated wiring to justify it.

For tests, pass fakes or in-memory implementations directly through constructors or local setup helpers.

# Compressed

No DI framework is used. Prefer explicit constructor parameters and clear ownership for repositories, controllers, formatters, and platform helpers. Use direct fakes in tests; avoid service locators unless repeated wiring makes one worthwhile.
