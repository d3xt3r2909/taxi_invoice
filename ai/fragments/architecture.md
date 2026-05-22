---
id: architecture
kind: instruction
title: Architecture and package boundaries
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

Project layout:

- `lib/main.dart`: app entry point and top-level app wiring
- `lib/src/store/`: invoice and recipient models, persistence, and store controller logic
- `lib/src/pdf/`: PDF construction and document layout
- `lib/src/template/`: static invoice copy/content used by generated documents
- `lib/src/ui/`: screens, presentation widgets, date formatting, and color scheme
- `lib/src/settings/`: app settings controller
- `lib/src/util/`: platform-specific save/reveal helpers and small utilities
- `assets/fonts/`: bundled PDF fonts and their license

Keep data/model logic out of UI widgets where practical. Keep PDF rendering code deterministic and independent from Flutter widget state. Platform-specific behavior should stay behind existing `*_io.dart` and `*_web.dart` helper files.

Prefer small, focused files over broad utility modules. Add new folders only when there is a clear boundary that matches the existing layout.

# Compressed

Use the existing `lib/src` boundaries: store for models/persistence, pdf for document generation, template for static document content, ui for screens, settings for settings state, and util for platform helpers. Keep PDF generation deterministic and platform-specific logic behind `*_io.dart`/`*_web.dart`.
