# Parallax

Multi-model coding-agent orchestration for Claude Code.

The orchestrator is Claude (Fable). Its scarcest resource is its own context window, so it **delegates all bulk work** — planning, building, reviewing — to subagent lanes (Opus personas, or Codex/Grok driven through the `bin/` engine tools) and keeps only the compact artifacts they hand back. The build worker spawns the review lanes itself (nested subagents) and fixes or rebuts every finding with its build context still hot. Fable spends its own intelligence at exactly two points: authoring the plan, and a final gate review of the diff. The deliberate split is **code with Opus, review with Codex** — cross-model review is genuinely independent.

Explicit `/plx:*` commands run a specific pipeline (`dev`, `plan-goal`, `review`), hand a task to a single engine, or bootstrap a repo's agent-docs setup (`init`) — see [`docs/COMMANDS.md`](docs/COMMANDS.md). Which engine fills each pipeline role is configurable in [`config/parallax.yaml`](config/parallax.yaml).

## Install

```text
/plugin marketplace add dshap474/parallax
/plugin install plx@parallax-marketplace
/reload-plugins
```

Then, in any repo:

```text
/plx:dev add a lollipop chart type to the plotting library
```

## What happens

Each pipeline establishes repo ground truth (Bootstrap), then runs its steps. Each pipeline is a fully self-contained skill — its steps, lane briefs, and engine invocations are all written out inline in its own `SKILL.md`.

| Pipeline | Use case | Lanes |
|---|---|---|
| `dev` | build a change end to end (plan → build+review → final gate → docs + local commit) | 2 planners + 1 worker (which spawns 2 reviewers) + docs |
| `plan-goal` | lock a goal, then plan it (no edits) | interview + 2 parallel planners |
| `review` | audit / debug / critique without edits | 2 parallel Codex review lanes |

`plan-goal` runs a Socratic interview to lock a goal, then multi-model planning, and writes one self-contained, `/goal`-ready spec into a build thread under `.project/builds/` (for long-running efforts); `review` is the review stage run standalone by the orchestrator (read-only). Single-engine passthroughs `/plx:codex` and `/plx:grok` hand a task straight to one engine with no review pipeline.

Plan and review lanes are always read-only. There is exactly **one writer at a time, always** (the build worker, plus Fable fixing nits at the final gate). Parallax does not write repo-local runtime state; temporary prompt/output files live only in shell temp directories and are cleaned up before commands return.

### The dev pipeline (7 steps)

1. Delegate planning to two parallel planner lanes — `claude-planner` (Opus, xhigh) and `codex-planner` (Codex, xhigh) — architecture consultants on the same neutral brief.
2. Both Planning Briefs return — recommendation + steelman + repo facts, not finished plans.
3. Fable arbitrates across the briefs and authors the final plan doc — a judgment-and-authoring pass, not a merge.
4. Delegate the build to one Opus worker (`claude-worker`) — the spec plus the reviewer persona names. The worker implements, self-verifies, **spawns the two Codex review lanes itself** (nested subagents, in parallel), then fixes or rebuts every finding with its build context still hot. One round, hard cap.
5. The Buildout report returns — per-file summaries, coding decisions, verification, and the disposition of every review finding (fixed / rebutted / residual). Never code bodies.
6. Fable gates the work: reads the diff once, with fresh eyes — do the rebuttals hold, do the residuals matter, was anything missed? It fixes nits inline (escape hatch: structural rework goes back through a fresh build), then re-runs the repo's checks.
7. A docs subagent updates docs, then a **local commit** — never a push or PR.

Exactly **four top-level subagent spawns** (2 planners + 1 builder + 1 docs); the builder spawns the 2 review lanes nested inside its own context.

### Configuring engines

`config/parallax.yaml` binds each pipeline role to an engine. `code` takes exactly one engine (one writer at a time); `plan` and `review-*` roles take lists and are always read-only. Plan authoring and the final gate are always the orchestrator; finding triage in the build's review round is always the build worker. Neither is configurable.

## Requirements

Parallax orchestrates external model CLIs you install and authenticate yourself. It does not bundle, host, or proxy any model.

| Engine | Install | Used by |
|---|---|---|
| Codex | `codex` CLI + auth | `dev`/`plan-goal`/`review` review and plan lanes; `/plx:codex` |
| Grok | `grok` CLI + auth | `/plx:grok` passthrough; parked for future ultra tiers |

The default `dev`, `plan-goal`, and `review` pipelines need Codex (planners and reviewers run on it). See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Architecture

Three stage atoms — `plan`, `build`, `review` — compose into the pipelines. The safety model: plan and review lanes are read-only for every engine, invoked only through the read-only engine tools (`plx-codex-ro` / `plx-grok-ro`, on PATH from `bin/`); only the build worker writes, and a non-Claude writer goes through a scoped-write tool (`plx-codex-rw` / `plx-grok-rw`) that confines edits to the target repo. Engine wrappers never use `danger-full-access` / `--yolo`. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repo layout

```text
parallax/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/       # one dir per command; each SKILL.md is fully self-contained
├── config/       # parallax.yaml — engine-per-role bindings (dev, plan-goal, review)
├── bin/          # engine API on PATH (plx-codex-ro/-rw, plx-grok-ro/-rw, plx-preflight, plx-config, plx-skill, plx-link-claude)
├── agents/
└── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
```

Each `skills/<name>/SKILL.md` carries its entire pipeline inline — lane briefs, engine invocations — with no `${CLAUDE_PLUGIN_ROOT}`, no `lib/` or `prompts/` pointers, and no script injection. The one exception is shared reference templates, fetched via `plx-skill --ref` (e.g. `dev/spec-template`, `init/AGENTS.template`) — a `bin/` tool, not a path. Reusable rubrics and schemas live inside the agent persona files (rubrics-in-agents); the orchestrator hands each subagent the work, not the command.

## Disabled pipelines

The `team-*` and `ultra-*` skills are parked (their `SKILL.md` files are renamed `DISABLED.md`). When revived, they are regenerated from the dev spec in `.project/VISION.md` — the same skeleton with more engines in the read stages.

## Status

v0.1.0 draft.

## License

MIT — see [`LICENSE`](LICENSE).
