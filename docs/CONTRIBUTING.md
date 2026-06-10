# Contributing

Parallax is a Claude Code plugin: a router skill (`plx:auto`) plus fully self-contained `/plx:*` pipeline skills, six per-engine subagents, a reference prompt library, and a deterministic engine API in `bin/`.

## Project Layout

```text
.claude-plugin/   plugin.json + marketplace.json
skills/           one dir per command — each SKILL.md is fully self-contained (auto, dev, team-dev, …)
config/           engine-per-role bindings (parallax.yaml)
bin/              engine API on PATH (plx-codex-ro/-rw, plx-grok-ro/-rw, plx-preflight, plx-config, plx-skill)
base-prompts/     reference prompt library (plan, code, refine, debug, correctness, synthesis, spec) — storage only
templates/        (reserved)
agents/           per-engine reviewer/worker subagents
docs/             human-facing docs
```

Only the two manifests belong under `.claude-plugin/`. Do not put `skills/`, `agents/`, or hooks under `.claude-plugin/`.

## Design rule: self-contained skills

Each `skills/<name>/SKILL.md` carries its **entire** pipeline inline — ordered steps, lane briefs, prompt templates, engine invocations, neutral-context rule. No pointers to other prompt files, no `!`-command script injection. The only external inputs a skill has are `config/parallax.yaml` (role→engine bindings) and the wrapper scripts.

`base-prompts/` holds the base prompt texts as an editable reference library. It is never loaded at runtime. **Editing a base prompt does not change the skills** — if you improve a base prompt, hand-propagate the change into every skill that inlines it (and vice versa).

## Common Changes

### Change a lane brief or pipeline step

Edit it directly in the skill's `SKILL.md`. If the change is generic (not skill-specific), also update the matching file in `base-prompts/` and the other skills that inline the same text.

### Add or change a pipeline

Copy the closest existing skill (`skills/team-dev/SKILL.md` is the richest template), write the whole pipeline out in the new `SKILL.md`, and add its config key to `config/parallax.yaml`.

### Change routing

`/plx:auto` selection criteria and preflight policy live inline in `skills/auto/SKILL.md`.

### Add Runtime Plumbing

Add executables under `bin/` (chmod +x; named `plx-*`). Claude Code puts `bin/` on the Bash tool's PATH while the plugin is enabled, so skills and agents invoke tools by bare name. Follow the API contract: `--repo` / `--prompt-file` / `--stdout` flags, exit codes 0 (ok) · 1 (engine failure) · 2 (usage error) · 3 (auth needed), and a `--help` that documents the tool. External model execution must stay inside the engine tools:

- Codex: `bin/plx-codex-ro` (review) / `bin/plx-codex-rw` (scoped write)
- Grok: `bin/plx-grok-ro` (review) / `bin/plx-grok-rw` (scoped write)

### Add or Change an Engine

Add `bin/plx-<engine>-ro` / `bin/plx-<engine>-rw` following the API contract, add an `agents/<engine>-{reviewer,worker}.md` pair carrying the engine's operator manual, update the "Running a lane" section in each pipeline skill that should be able to use it, and reference the engine name from `config/parallax.yaml`.

### Add a Subagent

Add `agents/<name>.md` with frontmatter. Installed agents appear under the `plx:` namespace.

## Testing

Run the acceptance checks from `docs/SPEC.md` before release. At minimum verify:

- `/plx:auto` resolves and the `/plx:*` command wrappers appear
- `bin/plx-*` tools are executable and answer `--help`
- `plx-preflight --repo <repo>` uses temporary files only
- skills are self-contained (no references to `lib/`, `prompts/`, `scripts/`, `router.md`, or `${CLAUDE_PLUGIN_ROOT}` — `tests/check-plugin.sh` enforces this)
- raw external model commands appear only inside the engine tools, outside docs
- no hooks or `.parallax/` runtime state exists

## Release Notes

Do not push, tag, open PRs, or publish from automation unless the current user request explicitly asks for that publication step.
