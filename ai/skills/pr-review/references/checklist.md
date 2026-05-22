# PR Review Checklist

- Does the change match the requested behavior and preserve existing behavior outside scope?
- Are local boundaries respected between UI, store, PDF, template, settings, and platform helpers?
- Are Dart imports consistent with nearby files?
- Are nullability checks explicit without unnecessary `!`?
- Do invoice, customer, recipient, and payment flows avoid leaking sensitive data?
- Are error messages actionable without exposing private invoice data?
- Are tests focused on behavior rather than implementation detail?
- Are generated PDF contents, persistence behavior, and import/export flows covered when changed?
- Are TODO comments handled as intentional placeholders unless they violate repo policy?
