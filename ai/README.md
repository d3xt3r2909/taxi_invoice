# AI Instruction Compiler

`ai/**` is the source of truth for shared AI instructions, platform mappings, and skills. Native tool files outside `ai/**` are generated for the platforms that require them.

Run:

```bash
scripts/ai validate
scripts/ai generate
scripts/ai generate --check
scripts/ai list
scripts/ai explain <generated-path>
```

Generated files include a trace header. Generated skill directories include `.ai-manifest.json`. Do not edit owned generated paths directly; change the source files under `ai/**` and regenerate.

Legacy native instruction files that were migrated into fragments are preserved under `ai/references/migrated/` for audit and future extraction.

Docs:

- `ai/CREATE.md`: how to add fragments, skills, and platforms
- `ai/PLATFORMS.md`: supported platforms and generated paths
- `ai/VALIDATION.md`: validation rules and common failures
- `ai/UPDATE.md`: update workflow
- `ai/EXAMPLES.md`: concrete examples
