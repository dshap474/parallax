# Parallax command surface (`/plx:*`)

Every entry point lives under the `plx` plugin namespace. The router is `/plx:auto`; the commands below force a specific pipeline or a single engine.

## Router

| Command | What it does |
|---|---|
| `/plx:auto` (or `/plx` + Tab) | Auto-router — reads the task and dispatches to `dev`, `plan`, or `review`. |

## Pipelines

| Command | What it does |
|---|---|
| `/plx:dev` | The full 10-step pipeline — 2 parallel planners → Fable synthesizes the plan → 1 Opus worker builds → 3 parallel Codex review lanes → Fable synthesizes + fixes inline → docs + local commit. |
| `/plx:plan` | Planning only (dev steps 1–3): two parallel planners draft, Fable synthesizes the final plan. No code is written. |
| `/plx:review` | Multi-lane review (dev steps 6–8): three parallel Codex lanes — debug, correctness, refine — plus Fable as pseudo-fourth reviewer. Read-only; does not edit unless you explicitly ask for fixes. |

## Single-engine asks (raw passthrough — no review pipeline)

Adapts to intent: ask a question → it answers; ask for code → it edits; ask for a plan → it writes one.

| Command | Engine |
|---|---|
| `/plx:codex` | Codex (headless `codex exec`) |
| `/plx:grok` | Grok Composer (headless) |

There is no `/plx:claude` — the orchestrator *is* Claude; just ask it directly.

## Disabled / parked commands

The `team-*` and `ultra-*` commands (`/plx:team-dev`, `/plx:ultra-dev`, `/plx:team-plan`, `/plx:ultra-plan`, `/plx:team-review`, `/plx:ultra-review`) are parked — their skill files are renamed `DISABLED.md` and the commands do not appear until they are regenerated from `.project/VISION.md`.

## Notes

- Each command **is** its pipeline, written out in full: its `SKILL.md` carries the ordered steps, lane briefs, prompt templates, and engine invocations inline, resolving only engine bindings from `config/parallax.yaml`. The router (`/plx:auto`) picks one and runs it.
- Each lane runs as an engine-named subagent (`plx:claude-planner`, `plx:codex-debug-reviewer`, etc.) so the TUI shows which engine ran it.
