# Parallax — Package Specification

Status: draft v0.1

## Purpose

Parallax packages a multi-model coding workflow as an installable Claude Code plugin. Its primary entry point is the router skill:

```text
/plx:auto <task>
```

The router establishes repo ground truth (Bootstrap), then dispatches to one of three pipelines:

```text
dev | plan | review
```

Explicit `/plx:*` commands can force a specific pipeline or a single engine without routing (see `docs/COMMANDS.md`).

The orchestrator is Claude (Fable). It delegates all bulk work — planning, building, reviewing — to subagent lanes and spends its own intelligence only at plan synthesis and review synthesis + fix. Plan and review lanes are read-only; there is exactly one writer at a time (the build worker, plus Fable applying the repair plan). By default the writer is Claude, but `config/parallax.yaml` can bind it to Codex or Grok (scoped-write tools).

## What ships

- 1 router skill: `plx:auto` (dispatches to a pipeline)
- 3 pipeline skills, each **fully self-contained** (steps, lane briefs, prompt templates, and engine handoffs all written out inline — no pointers to other prompt files, no `${CLAUDE_PLUGIN_ROOT}`, no script injection): `plx:dev` (10-step pipeline), `plx:plan` (steps 1–3), `plx:review` (steps 6–8)
- 2 single-engine passthroughs: `plx:codex`, `plx:grok` (no `plx:claude` — the orchestrator *is* Claude)
- Subagent personas in `agents/` carrying rubrics + operator manuals: `claude-planner`, `codex-planner`, `claude-worker`, `codex-debug-reviewer`, `codex-correctness-reviewer`, `codex-refine-reviewer`, plus legacy `claude-reviewer`, `codex-reviewer`, `codex-worker`, `grok-reviewer`, `grok-worker` (kept for passthrough + future ultra tiers)
- `base-prompts/` — canonical prompt blocks (rubrics, schemas, templates) as a **reference library only**, never loaded at runtime; skills inline the blocks and agents carry the rubrics
- 1 engine-per-role config (`config/parallax.yaml`), keyed by pipeline: `dev`, `plan`, `review`
- A deterministic engine API in `bin/` (on the Bash PATH while the plugin is enabled): `plx-codex-ro`/`plx-codex-rw`, `plx-grok-ro`/`plx-grok-rw`, `plx-preflight`, `plx-config`, `plx-skill` — uniform flags (`--repo`, `--prompt-file`, `--stdout`/`--out --log`; `--effort low|medium|high|xhigh` on the Codex tools), uniform exit codes (0 ok · 1 engine failure · 2 usage error · 3 auth needed), and `--help` manuals
- **Disabled / parked:** `team-*` and `ultra-*` skills, with their `SKILL.md` renamed to `DISABLED.md` (in `skills/_disabled/`), regenerated from `.project/PLX.md` when revived

## Target tree

```text
.
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/             # subagent personas (planners, worker, reviewers, passthroughs)
├── skills/
│   ├── auto/SKILL.md    # router
│   ├── dev/SKILL.md      # 10-step pipeline
│   ├── plan/SKILL.md     # steps 1–3
│   ├── review/SKILL.md   # steps 6–8
│   ├── codex/SKILL.md    # single-engine passthrough
│   ├── grok/SKILL.md     # single-engine passthrough
│   └── _disabled/        # parked team-*/ultra-* (DISABLED.md)
├── config/             # parallax.yaml — engine-per-role bindings
├── bin/                # engine API on PATH (plx-* tools)
├── base-prompts/       # canonical prompt blocks — storage only, not loaded at runtime
├── templates/          # plan / coding spec templates
├── docs/
├── tests/
├── LICENSE
└── README.md
```

## Plugin identity

`plugin.json` uses:

```json
{
  "name": "plx",
  "version": "0.1.0"
}
```

`marketplace.json` uses:

```json
{
  "name": "parallax-marketplace"
}
```

The skill path `skills/auto/SKILL.md` maps to `/plx:auto`.

## Runtime rules

- Each pipeline is a **self-contained skill**: its ordered steps, lane briefs, prompt templates, and engine invocations are all inline in its `SKILL.md`; only engine bindings come from `config/parallax.yaml`. `/plx:auto` routes; `/plx:*` commands force a pipeline.
- No prompt injection: skills contain no `!`-command injection and no pointers to external prompt files (`lib/`, `prompts/`, `scripts/`, `router.md`) or `${CLAUDE_PLUGIN_ROOT}`. `base-prompts/` is reference storage only.
- Reusable rubrics, schemas, and templates live in the agent files (rubrics-in-agents); the orchestrator hands each subagent only a task-specific brief.
- No hooks in v0.1.
- No repo-local runtime state. Do not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- The orchestrator establishes repo ground truth itself (Bootstrap: `git rev-parse --show-toplevel`, `git status --short`).
- Preflight and wrappers use shell temp directories only and clean them up before returning.
- Codex execution goes through `bin/plx-codex-ro` (review/plan) or, when `code: codex`, `bin/plx-codex-rw` (scoped write).
- Grok execution goes through `bin/plx-grok-ro` (review/plan) or, when `code: grok`, `bin/plx-grok-rw` (scoped write).
- Engine wrappers never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, or `--yolo`.
- Synthesis (plan merge, finding triage, repair planning) is always the orchestrator and never configurable.
- Plan and review lanes are always read-only; exactly one writer at a time.
- Every `dev` run ends with a docs subagent and a **local commit only** — never a push, PR, or publish step.
- Final results are returned in chat, not written to a results file.

## Contracts

The shapes that flow between stages (byte-identical wherever they appear):

1. **Plan artifact** — goal, ordered steps, files touched, risks, verification strategy. Output of each planner; Fable's synthesis of two is the final plan / build spec.
2. **Buildout report** — every file touched, per-file summary of changes, coding decisions, verification (commands + results), blockers/skips. Summaries only, never code bodies. Output of `build`; source of `review`'s brief.
3. **Review brief** — files touched + what was implemented and why. The only thing the orchestrator writes for the review stage.
4. **Finding Schema** — id, severity, file:line, what breaks, minimal fix, confidence. Output of every review lane; input to Fable's synthesis.
5. **Repair plan** — Fable's synthesis of findings plus its own pseudo-reviewer pass. Applied inline by Fable (or, escape hatch, becomes a fresh build spec).

## Acceptance criteria

These mirror the deterministic checks run by `tests/run.sh`.

### File structure

```bash
test -f skills/auto/SKILL.md
test -f skills/dev/SKILL.md
test -f skills/plan/SKILL.md
test -f skills/review/SKILL.md
test -f config/parallax.yaml
test -d bin
test -d skills/_disabled
```

### Engine API (bin/)

```bash
test -x bin/plx-preflight
test -x bin/plx-codex-ro
test -x bin/plx-codex-rw
test -x bin/plx-grok-ro
test -x bin/plx-grok-rw
test -x bin/plx-config
test -x bin/plx-skill
bin/plx-codex-ro --help | grep -q "Usage:"
bin/plx-config | grep -q "pipelines:"
```

### No runtime state

```bash
test ! -d .parallax
```

### Self-contained skills

No skill points at external prompt files, plugin-root paths, or uses `!`-command injection:

```bash
! grep -rE 'lib/(pipeline|engines)\.md|prompts/|scripts/|router\.md' skills/*/SKILL.md
! grep -r 'CLAUDE_PLUGIN_ROOT' skills/ agents/
```

### Runtime tool safety

Raw engine CLIs may appear only inside the engine API tools (the read-only `plx-*-ro` and scoped-write `plx-*-rw` ones) — never in skills, agents, or ad-hoc scripts:

```bash
! grep -R "codex exec" . --exclude-dir=.git --exclude='plx-codex-ro' --exclude='plx-codex-rw' --exclude='*.md'
! grep -R "grok --"   . --exclude-dir=.git --exclude='plx-grok-ro'  --exclude='plx-grok-rw'  --exclude='*.md'
```

### Plugin namespace

After local install:

```text
/plugin marketplace add ./
/plugin install plx@parallax-marketplace
/reload-plugins
```

Expected:

```text
/plx:auto, /plx:dev, /plx:plan, /plx:review, /plx:codex, /plx:grok appear (no /plx:claude)
plx:claude-planner / plx:codex-planner appear in /agents
plx:claude-worker appears in /agents
plx:codex-debug-reviewer / plx:codex-correctness-reviewer / plx:codex-refine-reviewer appear in /agents
```

### Smoke tests

Preflight smoke (model-free):

```bash
bin/plx-preflight --repo "$(pwd)"
test ! -d .parallax
```

Engine probe (spends a tiny model call each, env-dependent):

```bash
bin/plx-preflight --repo "$(pwd)" --require-codex
```

Expected: Codex preflight passes (or reports a clear auth/missing error with exit code 3); no empty engine output treated as success; no `.parallax/` directory is created.
