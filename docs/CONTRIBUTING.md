# Contributing

Parallax is a Claude Code plugin with one public skill, two subagents, shared reference briefs, and deterministic runtime scripts.

## Project Layout

```text
.claude-plugin/   plugin.json + marketplace.json
skills/plx/       public router skill, mode docs, references, scripts
agents/           reviewer.md, worker.md
docs/             human-facing docs
_source/          canonical references
scripts/          repo maintenance helpers
```

Only the two manifests belong under `.claude-plugin/`. Do not put `skills/`, `agents/`, or hooks under `.claude-plugin/`.

## Shared References

Each skill carries its own `references/` directory because plugin skill body text cannot reliably read one shared root-level reference directory.

Edit `_source/references/`, then sync:

```bash
bash scripts/sync-references.sh
git add _source/references skills/plx/references
```

Do not edit `skills/plx/references/` directly unless you are intentionally debugging sync output.

## Common Changes

### Add or Change a Mode

Do not add public skills for new modes. Add the mode behavior to `skills/plx/modes.md` and add routing rules to `skills/plx/router.md`.

### Add Runtime Plumbing

Add deterministic helpers under `skills/plx/scripts/`. External model execution must stay inside wrappers:

- Codex: `skills/plx/scripts/codex-ro.sh`
- Grok: `skills/plx/scripts/grok-ro.sh`

### Add or Change an Engine

Update `_source/references/engines.md`, adjust wrapper scripts if needed, then sync references.

### Add a Subagent

Add `agents/<name>.md` with frontmatter. Installed agents appear under the `parallax:` namespace.

## Testing

Run the acceptance checks from `docs/SPEC.md` before release. At minimum verify:

- only `/parallax:plx` is public
- `skills/plx/scripts/*.sh` are executable
- `parallax-intake.sh` prints repo metadata without creating files
- `preflight.sh --repo <repo>` uses temporary files only
- references sync cleanly
- raw external model commands appear only in their wrappers outside docs
- no hooks or `.parallax/` runtime state exists

## Release Notes

Do not push, tag, open PRs, or publish from automation unless the current user request explicitly asks for that publication step.
