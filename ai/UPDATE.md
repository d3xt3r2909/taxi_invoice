# Update Workflow

To change always-on instructions, edit or add a fragment in `ai/fragments`, then update the relevant target assembly under `ai/targets`.

To change a skill, edit `ai/skills/<name>/skill.yml`, `instructions.md`, or its references.

To change platform limits or ownership, edit `ai/platforms/<platform>.yml`.

After every change, run:

```bash
scripts/ai validate
scripts/ai generate
scripts/ai generate --check
scripts/ai list
```

Commit both the `ai/**` source change and generated native outputs.
