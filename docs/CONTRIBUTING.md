# Contributing

Parallax is a Claude Code plugin: three fully self-contained pipeline skills (`dev`, `plan`, `review`), two single-engine passthroughs (`codex`, `grok`), subagent personas in `agents/`, a canonical prompt block library, and a deterministic engine API in `bin/`.

## Project layout

```text
.claude-plugin/   plugin.json + marketplace.json
skills/           one dir per command — each SKILL.md is fully self-contained (dev, plan, review, codex, grok)
skills/_disabled/ parked team-*/ultra-* skills (DISABLED.md)
config/           engine-per-role bindings (parallax.yaml — keys: dev, plan, review)
bin/              engine API on PATH (plx-codex-ro/-rw, plx-grok-ro/-rw, plx-preflight, plx-config, plx-skill)
base-prompts/     canonical prompt blocks (rubrics, schemas, templates) — storage only
templates/        plan / coding spec templates
agents/           subagent personas (planners, worker, dimension reviewers, passthroughs)
docs/             human-facing docs
tests/            deterministic harness (run.sh, check-plugin.sh, explain-skill.sh, smoke-scripts.sh, fixture/)
```

Only the two manifests belong under `.claude-plugin/`. Do not put `skills/`, `agents/`, or hooks under `.claude-plugin/`.

## Design rule: self-contained skills

Each `skills/<name>/SKILL.md` carries its **entire** pipeline inline — ordered steps, lane briefs, prompt templates, engine invocations, neutral-context rule. No pointers to other prompt files (`lib/`, `prompts/`, `scripts/`, `router.md`), no `${CLAUDE_PLUGIN_ROOT}`, no `!`-command injection. The only external inputs a skill has are `config/parallax.yaml` (role→engine bindings) and the `bin/` tools, invoked by bare name.

## Design rule: rubrics live in the agents

Any prompt text that is the same every run — the plan rubric, the review dimension rubrics, the Finding Schema, output templates — lives in the **agent files**, alongside each engine agent's operator manual for the `plx-*` tools. The orchestrator hands a subagent only a task-specific brief (repo path + the work). Hand the subagent **the work, not the command**.

`base-prompts/` holds the canonical block text as a reference library. It is never loaded at runtime. **Editing a base prompt does not change the skills or agents** — propagate the change by hand into every file that inlines it.

## Common changes

### Change a lane brief or pipeline step

Edit it directly in the skill's `SKILL.md`. If the change is a reusable block (a rubric, the Finding Schema, a template), update the agent file that carries it and the matching `base-prompts/` block too.

### Revive a disabled pipeline

The `team-*` and `ultra-*` skills are regenerated from `.project/VISION.md` — the dev skeleton with more engines in the read stages. A revived team/ultra skill must read as "the dev stages with more read lanes"; if it doesn't, the structure has drifted. Add its config key to `config/parallax.yaml`.

### Add runtime plumbing

Add executables under `bin/` (chmod +x; named `plx-*`). Claude Code puts `bin/` on the Bash tool's PATH while the plugin is enabled, so skills and agents invoke tools by bare name. Follow the API contract: `--repo` / `--prompt-file` / `--stdout` (or `--out --log`) flags, exit codes 0 (ok) · 1 (engine failure) · 2 (usage error) · 3 (auth needed), and a `--help` that documents the tool. External model execution must stay inside the engine tools, and wrappers never use `danger-full-access` / `--yolo`:

- Codex: `bin/plx-codex-ro` (read-only) / `bin/plx-codex-rw` (scoped write)
- Grok: `bin/plx-grok-ro` (read-only) / `bin/plx-grok-rw` (scoped write)

### Add or change an engine

Add `bin/plx-<engine>-ro` / `bin/plx-<engine>-rw` following the API contract, add `agents/<engine>-{planner,worker,correctness-reviewer,refine-reviewer}.md` personas carrying the engine's operator manual plus the relevant rubric, update the lane invocations in each pipeline skill that should use it, and reference the engine name from `config/parallax.yaml`.

### Add a subagent

Add `agents/<name>.md` with frontmatter. Installed agents appear under the `plx:` namespace.

## Testing

Run the deterministic harness before any change lands:

```bash
bash tests/run.sh
```

It runs `check-plugin.sh` (wiring + self-containment), `explain-skill.sh` (dry-run projection), and `smoke-scripts.sh` (real shell scripts against a tmp copy of `fixture/`). Pass `--with-engines` to also probe Codex/Grok auth (spends a tiny model call). At minimum verify:

- the `/plx:*` command wrappers appear
- `bin/plx-*` tools are executable and answer `--help`
- `plx-preflight --repo <repo>` uses temporary files only
- skills are self-contained (no `lib/`, `prompts/`, `scripts/`, `router.md`, or `${CLAUDE_PLUGIN_ROOT}` — `tests/check-plugin.sh` enforces this)
- raw external model commands appear only inside the engine tools
- no hooks or `.parallax/` runtime state exists

## Release notes

Do not push, tag, open PRs, or publish from automation unless the current user request explicitly asks for that publication step.
