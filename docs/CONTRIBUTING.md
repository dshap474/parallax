# Contributing

Parallax is a Claude Code plugin: five fully self-contained pipeline skills (`plan`, `build`, `review`, `dev`, `goal-spec`), two single-engine passthroughs (`codex`, `grok`), a setup skill (`init`), lane rubrics in `prompts/`, and a deterministic engine API in `bin/`. There are no subagents — the orchestrator drives every engine headless through `plx-engine`.

## Project layout

```text
.claude-plugin/   plugin.json + marketplace.json
skills/           one dir per command — each SKILL.md is fully self-contained (plan, build, review, dev, goal-spec, codex, grok, init)
prompts/          lane rubrics (reviewer-correctness/cleanup/structural, planner, plan-critic, worker) + engines.md judgment doc
config/           default engine bindings (parallax.yaml — keys: plan, build, review, dev, goal-spec)
bin/              engine API on PATH (plx-engine, plx-preflight, plx-config, plx-skill, plx-link-claude)
docs/             human-facing docs
tests/            deterministic harness (run.sh, check-plugin.sh, explain-skill.sh, smoke-scripts.sh, fixture/) + behavioral smoke/ suite
```

Only the two manifests belong under `.claude-plugin/`. Do not put `skills/` or hooks under `.claude-plugin/`.

## Design rule: self-contained skills

Each `skills/<name>/SKILL.md` carries its **entire** pipeline inline — ordered steps, lane briefs, engine invocations, neutral-context rule. No path pointers (`prompts/`, `lib/`, `scripts/`), no `${CLAUDE_PLUGIN_ROOT}`, no `!`-command injection. The only external inputs a skill has arrive through `bin/` tools invoked by bare name: `config/parallax.yaml` bindings via `plx-config`, shared reference templates via `plx-skill --ref` (e.g. `plan/spec-template`, `init/AGENTS.template`), and rubrics via `plx-engine --rubric <name>`.

## Design rule: rubrics live in `prompts/`

Any prompt text that is the same every run — the lane rubrics, the Finding Schema, output templates — lives in `prompts/`, one deduped engine-agnostic file per lane. Skills reference a rubric by bare `--rubric` name only; `plx-engine` resolves `prompts/` relative to itself and injects the text (prepended to the prompt for codex/grok, `--append-system-prompt-file` for claude). Never paste rubric text into a brief, and never point a skill at a `prompts/` path. The brief file must open with the section header the rubric expects (`## Review brief`, `## Task brief`, `## Draft plan`, `## Spec`).

## Common changes

### Change a lane brief or pipeline step

Edit it directly in the skill's `SKILL.md`.

### Change a rubric

Edit the one file in `prompts/`. Every engine gets the same text — there is nothing to propagate. If you change the expected brief header, update every skill that writes that brief.

### Add runtime plumbing

Add executables under `bin/` (chmod +x; named `plx-*`). Claude Code puts `bin/` on the Bash tool's PATH while the plugin is enabled, so skills invoke tools by bare name. Follow the API contract: `--repo` / `--prompt-file` / `--stdout` (or `--out --log`) flags, exit codes 0 (ok) · 1 (engine failure) · 2 (usage error) · 3 (auth needed), and a `--help` that documents the tool. External model execution must stay inside `plx-engine`, and wrappers never use `danger-full-access` / bypass flags / `--yolo`. Mind macOS: system bash is 3.2 — no `declare -A`, and empty-array expansion under `set -u` needs the `${arr[@]+"${arr[@]}"}` guard.

### Add or change an engine

Add a `run_<engine>()` branch to `bin/plx-engine` with its safety pinned in code (config isolation, sandbox or permission-mode scoping for ro/rw), teach `plx-preflight` to probe it, document it in `prompts/engines.md` (characteristics + choice guidance) and `docs/REQUIREMENTS.md`, and reference the engine name from `config/parallax.yaml` where a pipeline should default to it.

### Add a rubric (new lane type)

Add `prompts/<name>.md`, opening with the brief-header contract it expects. Reference it from skills as `--rubric <name>`. `tests/check-plugin.sh` verifies every referenced rubric exists.

## Testing

Run the deterministic harness before any change lands:

```bash
bash tests/run.sh
```

It runs `check-plugin.sh` (wiring + self-containment + rubric resolution), `explain-skill.sh` (dry-run projection), and `smoke-scripts.sh` (real shell scripts against a tmp copy of `fixture/`). Pass `--with-engines` to also probe engine auth (spends a tiny model call). At minimum verify:

- the `/plx:*` command wrappers appear
- `bin/plx-*` tools are executable and answer `--help`
- every `--rubric` name a skill references resolves to `prompts/<name>.md`
- skills are self-contained (no `prompts/` paths, `lib/`, `scripts/`, or `${CLAUDE_PLUGIN_ROOT}` — `tests/check-plugin.sh` enforces this)
- raw external model commands appear only inside `plx-engine`
- no hooks or `.parallax/` runtime state exists

`tests/smoke/` is the behavioral end-to-end suite — it makes real model calls and spends tokens; run it deliberately, not as part of routine changes.

## Release notes

Do not push, tag, open PRs, or publish from automation unless the current user request explicitly asks for that publication step.
