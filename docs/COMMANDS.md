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
| **plan** — think only, no edits | `/plx:plan` ⛏️ | `/plx:team-plan` ⛏️ | `/plx:ultra-plan` ⛏️ |
| **dev** — build | `/plx:dev` ✅ | `/plx:team-dev` ✅ | `/plx:ultra-dev` ✅ |
| **review** — audit, no edits | `/plx:review` ✅ | `/plx:team-review` ⛏️ | `/plx:ultra-review` ⛏️ |

## Single-engine asks (raw passthrough — no review pipeline)

Adapts to intent: ask a question → it answers; ask for code → it edits; ask for a plan → it writes one.

| Command | Engine |
|---|---|
| `/plx:claude` ✅ | Claude (native orchestrator), directly |
| `/plx:codex` ✅ | Codex (headless) via `plx:codex-worker` |
| `/plx:grok` ⛏️ | Grok Composer 2.5 (headless) via `plx:grok-worker` — pending write-probe |

✅ implemented · ⛏️ scaffold (README/stub; intended behavior documented in the file)

## Notes

- `quick` and `panel` from the old single-axis modes are folded into this grid: `quick` → `/plx:dev`, `panel` → adding Grok to the team review lanes in `config/parallax.yaml`.
- Each implemented command **is** its pipeline: its `SKILL.md` "## Pipeline" section composes prompt blocks from `prompts/` in order, resolving engines from `config/parallax.yaml` and following the shared grammar in `lib/pipeline.md`. The router (`/plx:auto`) selects one and runs its pipeline.
- Each lane runs as an engine-named subagent (`plx:<engine>-reviewer` / `-worker`) so the TUI shows which engine ran it.
