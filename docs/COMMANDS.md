# Parallax command surface (`/plx:*`)

Every entry point lives under the `plx` plugin namespace. The bare router is the
`plx` skill (`/plx:auto`); the commands below force a specific workflow.

## Router

| Command | What it does |
|---|---|
| `/plx:auto` (or `/plx` + Tab) | Auto-router — reads the task and picks the smallest workflow that gives enough assurance. |

## Stage × tier grid

Two axes: **stage** (what you want) × **tier** (how much assurance).

| stage \ tier | **solo** (1 agent) | **team** (multi-engine, per `parallax.yaml`) | **ultra** (multi-stage) |
|---|---|---|---|
| **plan** — think only, no edits | `/plx:plan` ✅ | `/plx:team-plan` ✅ | `/plx:ultra-plan` ✅ |
| **dev** — build | `/plx:dev` ✅ | `/plx:team-dev` ✅ | `/plx:ultra-dev` ✅ |
| **review** — audit, no edits | `/plx:review` ✅ | `/plx:team-review` ✅ | `/plx:ultra-review` ✅ |

## Single-engine asks (raw passthrough — no review pipeline)

Adapts to intent: ask a question → it answers; ask for code → it edits; ask for a plan → it writes one.

| Command | Engine |
|---|---|
| `/plx:codex` ✅ | Codex (headless `codex exec`) via `plx:codex-worker` → `plx-codex-rw` |
| `/plx:grok` ✅ | Grok Composer (headless) via `plx:grok-worker` → `plx-grok-rw` (kernel `workspace` sandbox) |

There is no `/plx:claude` — the orchestrator *is* Claude; just ask it directly.

✅ implemented

## Notes

- `quick` and `panel` from the old single-axis modes are folded into this grid: `quick` → `/plx:dev`, `panel` → adding Grok to the team review lanes in `config/parallax.yaml`.
- Each command **is** its pipeline, written out in full: its `SKILL.md` carries the ordered steps, lane briefs, prompt templates, and engine invocations inline, resolving only engine bindings from `config/parallax.yaml`. The router (`/plx:auto`) selects one and runs its pipeline.
- Each lane runs as an engine-named subagent (`plx:<engine>-reviewer` / `-worker`) so the TUI shows which engine ran it.
