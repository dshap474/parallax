# Parallax

Multi-model coding-agent orchestration for Claude Code.

The orchestrator is Claude (Fable). Its scarcest resource is its own context window, so it **delegates all bulk work** — planning, building, reviewing — to subagent lanes (Opus personas, or Codex/Grok driven through the `bin/` engine tools) and keeps only the compact artifacts they hand back. Fable spends its own intelligence at exactly two points: synthesizing the plan, and synthesizing the review (then applying the fix). The deliberate split is **code with Opus, review with Codex** — cross-model review is genuinely independent.

Explicit `/plx:*` commands run a specific pipeline (`dev`, `plan`, `review`) or hand a task to a single engine (see [`docs/COMMANDS.md`](docs/COMMANDS.md)). Which engine fills each pipeline role is configurable in [`config/parallax.yaml`](config/parallax.yaml).

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
| `dev` | build a change end to end (plan → build → review → fix → docs + local commit) | 2 planners + 1 worker + 2 reviewers + docs |
| `plan` | think only, no edits | 2 parallel planners |
| `review` | audit / debug / critique without edits | 2 parallel Codex review lanes |

`plan` is steps 1–3 of `dev` run standalone; `review` is steps 6–8 run standalone (read-only). Single-engine passthroughs `/plx:codex` and `/plx:grok` hand a task straight to one engine with no review pipeline.

Plan and review lanes are always read-only. There is exactly **one writer at a time, always** (the build worker, plus Fable applying the repair plan inline). Parallax does not write repo-local runtime state; temporary prompt/output files live only in shell temp directories and are cleaned up before commands return.

### The dev pipeline (10 steps)

1. Delegate planning to two parallel planner lanes — `claude-planner` (Opus, xhigh) and `codex-planner` (Codex, xhigh) — architecture consultants on the same neutral brief.
2. Both Planning Briefs return — recommendation + steelman + repo facts, not finished plans.
3. Fable arbitrates across the briefs and authors the final plan doc — a judgment-and-authoring pass, not a merge.
4. Delegate the build to one Opus worker (`claude-worker`), spec only.
5. The Buildout report returns — per-file summaries of what changed and why, never code bodies.
6. Fable prepares a review brief from the report **without reading the built code** — its context stays clean.
7. Two parallel Codex review lanes fire — correctness, refine.
8. Fable synthesizes as the pseudo-third reviewer: verifies findings surgically, kills false positives, produces the repair plan.
9. Fable applies the repair plan inline (escape hatch: structural rework goes back through a fresh build), then runs the repo's checks.
10. A docs subagent updates docs, then a **local commit** — never a push or PR.

Exactly **six subagent spawns** (2 planners + 1 builder + 2 reviewers + 1 docs).

### Configuring engines

`config/parallax.yaml` binds each pipeline role to an engine. `code` takes exactly one engine (one writer at a time); `plan` and `review-*` roles take lists and are always read-only. Synthesis is always the orchestrator and never configurable.

## Requirements

Parallax orchestrates external model CLIs you install and authenticate yourself. It does not bundle, host, or proxy any model.

| Engine | Install | Used by |
|---|---|---|
| Codex | `codex` CLI + auth | `dev`/`plan`/`review` review and plan lanes; `/plx:codex` |
| Grok | `grok` CLI + auth | `/plx:grok` passthrough; parked for future ultra tiers |

The default `dev`, `plan`, and `review` pipelines need Codex (planners and reviewers run on it). See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Architecture

Three stage atoms — `plan`, `build`, `review` — compose into the pipelines. The safety model: plan and review lanes are read-only for every engine, invoked only through the read-only engine tools (`plx-codex-ro` / `plx-grok-ro`, on PATH from `bin/`); only the build worker writes, and a non-Claude writer goes through a scoped-write tool (`plx-codex-rw` / `plx-grok-rw`) that confines edits to the target repo. Engine wrappers never use `danger-full-access` / `--yolo`. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repo layout

```text
parallax/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/       # one dir per command; each SKILL.md is fully self-contained
├── config/       # parallax.yaml — engine-per-role bindings (dev, plan, review)
├── bin/          # engine API on PATH (plx-codex-ro/-rw, plx-grok-ro/-rw, plx-preflight, plx-config, plx-skill)
├── base-prompts/ # canonical prompt blocks — storage only, never loaded at runtime
├── templates/    # plan / coding spec templates
├── agents/
└── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
```

Each `skills/<name>/SKILL.md` carries its entire pipeline inline — lane briefs, prompt templates, engine invocations — with no `${CLAUDE_PLUGIN_ROOT}`, no `lib/` or `prompts/` pointers, and no script injection. Reusable rubrics and schemas live inside the agent persona files (rubrics-in-agents); the orchestrator hands each subagent the work, not the command. `base-prompts/` holds the canonical block text as a reference; changing one does not change the skills (propagate by hand).

## Disabled pipelines

The `team-*` and `ultra-*` skills are parked (their `SKILL.md` files are renamed `DISABLED.md`). When revived, they are regenerated from the dev spec in `.project/VISION.md` — the same skeleton with more engines in the read stages.

## Status

v0.1.0 draft.

## License

MIT — see [`LICENSE`](LICENSE).
