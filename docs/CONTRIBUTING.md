# Contributing

Parallax is a Claude Code plugin with one public skill, two subagents, shared reference briefs, and deterministic runtime scripts.

## Project Layout

```text
.claude-plugin/   plugin.json + marketplace.json
skills/plx/       public router skill, mode docs, references, scripts
agents/           reviewer.md, worker.md
docs/             human-facing docs
```

Only the two manifests belong under `.claude-plugin/`. Do not put `skills/`, `agents/`, or hooks under `.claude-plugin/`.

## Shared References

The runtime reference briefs live in `skills/plx/references/`. Edit those files directly.

## Common Changes

### Add or Change a Mode

Do not add public skills for new modes. Add the mode behavior to `skills/plx/modes.md` and add routing rules to `skills/plx/router.md`.

### Add Runtime Plumbing

Add deterministic helpers under `skills/plx/scripts/`. External model execution must stay inside wrappers:

- Codex: `skills/plx/scripts/codex-ro.sh`
- Grok: `skills/plx/scripts/grok-ro.sh`

### Add or Change an Engine

Update `skills/plx/references/engines.md` and adjust wrapper scripts if needed.

### Add a Subagent

Add `agents/<name>.md` with frontmatter. Installed agents appear under the `parallax:` namespace.

## Testing

Run the acceptance checks from `docs/SPEC.md` before release. At minimum verify:

- only `/parallax:plx` is public
- `skills/plx/scripts/*.sh` are executable
- `parallax-intake.sh` prints repo metadata without creating files
- `preflight.sh --repo <repo>` uses temporary files only
- runtime references exist under `skills/plx/references/`
- raw external model commands appear only in their wrappers outside docs
- no hooks or `.parallax/` runtime state exists

## Release Notes

Do not push, tag, open PRs, or publish from automation unless the current user request explicitly asks for that publication step.
