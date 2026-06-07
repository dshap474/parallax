# Contributing

Parallax is a Claude Code plugin: a router skill (`plx:auto`) plus thin `/plx:*` command wrappers, six per-engine subagents, shared review/spec briefs, and deterministic runtime scripts.

## Project Layout

```text
.claude-plugin/   plugin.json + marketplace.json
skills/auto/      router skill (SKILL.md, router.md)
skills/           pipeline skills — each composes blocks (team-dev, ultra-dev, review, dev, …)
config/           engine-per-role bindings (parallax.yaml)
scripts/          deterministic *.sh helpers + engine wrappers
prompts/          reusable step blocks (plan, code, refine, debug, correctness, synthesis, spec)
lib/              shared grammar + engine docs (pipeline.md, engines.md)
templates/        (reserved)
agents/           per-engine reviewer/worker subagents
docs/             human-facing docs
```

Only the two manifests belong under `.claude-plugin/`. Do not put `skills/`, `agents/`, or hooks under `.claude-plugin/`.

## Building blocks

Parallax is composed, not hardcoded:

- **`prompts/`** — reusable step *blocks* (the lego pieces): `plan.md`, `code.md`, `refine.md`, `debug.md`, `correctness.md`, `synthesis.md`, `coding-spec-template.md`.
- **`skills/`** — *pipelines*: each skill's "## Pipeline" section lists which blocks run in what order.
- **`lib/pipeline.md`** — the shared grammar every pipeline obeys (roles, engine binding, subagent injection, neutral-context rule).
- **`config/parallax.yaml`** — which engine fills each role, per pipeline.

Edit these files directly.

## Common Changes

### Add or change a block

Add or edit a file in `prompts/`. A block is a self-contained step instruction (matches the style of the existing blocks). Reference it from a skill's pipeline.

### Add or change a pipeline

Each pipeline is a skill — its order lives in that skill's "## Pipeline" section, composing blocks from `prompts/` and resolving engines from a `config/parallax.yaml` key. Edit the step list there; use `skills/team-dev/SKILL.md` as the template. Shared mechanics belong in `lib/pipeline.md`, not duplicated per skill.

### Change routing

`/plx:auto` selection criteria and preflight policy live in `skills/auto/router.md`.

### Add Runtime Plumbing

Add deterministic helpers under `scripts/`. External model execution must stay inside wrappers:

- Codex: `scripts/codex-ro.sh`
- Grok: `scripts/grok-ro.sh`

### Add or Change an Engine

Update `lib/engines.md` and adjust wrapper scripts if needed.

### Add a Subagent

Add `agents/<name>.md` with frontmatter. Installed agents appear under the `plx:` namespace.

## Testing

Run the acceptance checks from `docs/SPEC.md` before release. At minimum verify:

- `/plx:auto` resolves and the `/plx:*` command wrappers appear
- `scripts/*.sh` are executable
- `parallax-intake.sh` prints repo metadata without creating files
- `preflight.sh --repo <repo>` uses temporary files only
- runtime briefs exist under `prompts/` and shared reference docs under `lib/`
- raw external model commands appear only in their wrappers outside docs
- no hooks or `.parallax/` runtime state exists

## Release Notes

Do not push, tag, open PRs, or publish from automation unless the current user request explicitly asks for that publication step.
