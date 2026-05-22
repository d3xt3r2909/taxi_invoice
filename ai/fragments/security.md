---
id: security
kind: instruction
title: Security and safety
owner: security
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

Do not introduce secrets, tokens, local machine paths, or personal configuration into committed files.

Invoice data can contain names, addresses, invoice identifiers, tax-like details, routes, and payment details. Treat it as user data. Do not log or export it outside explicit user actions.

Error, assertion, and crash-report messages should be actionable from logs alone. Include which value or field was null or invalid, but do not include sensitive customer data.

# Compressed

Do not commit secrets, tokens, local paths, or personal config. Treat invoice/customer/recipient data as private user data. Make errors actionable without exposing sensitive details.
