# Contributing

Polyphony is a Claude Code plugin: two skills, two subagents, shared briefs, and a
one-repo marketplace. This doc covers how to change each part safely.

## Project layout

```
.claude-plugin/   plugin.json + marketplace.json  (the only files under here)
skills/<name>/    SKILL.md + references/  (references/ is generated — see below)
agents/           reviewer.md, worker.md
docs/             this folder
_source/          references/  ← the SINGLE source of truth for the briefs
scripts/          sync-references.sh
```

> **Never** put `skills/`, `agents/`, or `hooks/` under `.claude-plugin/`. Only the two
> manifests live there.

## The shared-references rule (read this first)

Each skill carries its **own copy** of the reference briefs in `skills/<name>/references/`.
This is deliberate: `${CLAUDE_PLUGIN_ROOT}` is unreliable inside `SKILL.md` body text
([claude-code #9354](https://github.com/anthropics/claude-code/issues/9354)), so a skill
can't reliably read one shared copy at the plugin root.

To stay DRY, the **canonical copy lives in `_source/references/`** and is mirrored into
each skill by a script. The per-skill `references/` dirs are build output — edit
`_source/`, never the copies.

```bash
# after editing anything in _source/references/:
bash scripts/sync-references.sh
git add _source/references skills/*/references
```

## Common changes

### Edit a brief or the engine cookbook
Edit the file in `_source/references/`, run `sync-references.sh`, commit both the source
and the synced copies.

### Swap a model for a role
Edit that role's row in the affected skill's `SKILL.md` engine roster, and/or the engine's
block in `_source/references/engines.md`. The pipeline and briefs don't change.

### Add a new engine
Add a block to `_source/references/engines.md` (invocation + safety + output discipline),
sync, then reference it from a skill's roster.

### Add a new skill (combo)
Create `skills/<name>/SKILL.md` with a frontmatter `name`, a `description` with trigger
phrases, `disable-model-invocation: true`, and `user-invocable: true`. Define its engine
roster, then `sync-references.sh` to populate its `references/`.

### Add a new subagent
Add `agents/<name>.md` with frontmatter (`name`, `description` with trigger conditions,
`model`, `color`, `tools`). It installs as `polyphony:<name>`.

## Testing a change

1. Install from your local checkout: `/plugin marketplace add ./` then
   `/plugin install polyphony@polyphony-marketplace`, and `/reload-plugins`.
2. Confirm skills appear as `/polyphony:team-dev` and `/polyphony:ultra-dev`, and the
   subagents in `/agents`.
3. Run `/polyphony:team-dev` on a real task on a **codex-only** machine — it must complete
   without grok.
4. Bump `version` in both `plugin.json` and the `marketplace.json` plugin entry.

## Roadmap / help wanted

- **v0.2 — finish `composer-ro`.** The Grok read-only engine is a stub. Verify grok's
  read-only invocation headless (the sandbox-disable + verify-by-file gotchas in
  `REQUIREMENTS.md`), then enable the Grok tier (`ultra-dev` + `team-dev`'s panel).
- Toolchain adapters for non-Python repos in the verification step.
