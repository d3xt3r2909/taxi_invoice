---
id: code-style
kind: instruction
title: Dart and Flutter style
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

Use absolute `package:` imports for app code when importing across `lib/src` areas. Local relative imports are acceptable inside tightly coupled platform implementation pairs when already used nearby.

Prefer extracting widgets over helper methods that return widgets. Keep shared widget structure in one place and branch only around the children or values that differ.

Avoid `!` for silencing nullability checks except when a test is explicitly verifying nullable behavior. Prefer local final variables so Dart type promotion can prove non-null values.

Use explicit, readable domain names instead of cryptic abbreviations. If an external API uses terse transport names, wrap them in clearer internal names.

Prefer the simplest idiomatic Dart API that expresses intent clearly. Use `map`, existing helpers, and direct transforms when they are clearer than manual loops.

When adding fields to `Equatable` classes, update `props`; every behavior-affecting field must participate in equality.

When a test imports a package directly, declare that package as a direct dependency or dev dependency. Do not rely on transitive test utility dependencies for direct imports.

Parsing helpers should make failure semantics explicit. If `fromString` can fail, it should throw on invalid input. If the intended behavior is non-throwing, name the helper `tryFromString` and return `null` or a result type.

# Compressed

Use clear imports, readable domain names, idiomatic Dart transforms, and narrow widget branches. Prefer widgets over methods returning widgets. Avoid null-assertion `!` unless a test intentionally needs it. Keep direct test imports declared in `pubspec.yaml` and make parsing failure semantics explicit.
