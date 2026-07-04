# Parallax command surface (`/plx:*`)

Every entry point lives under the `plx` plugin namespace. The commands below run a specific pipeline or hand a task to a single engine.

## Pipelines

| Command | What it does |
|---|---|
| `/plx:dev` | The full dev pipeline — Fable authors the plan → a cross-engine critic lane red-teams it → one writer lane builds → Fable runs three parallel read-only review lanes and synthesizes, fixing or rebutting every finding → final gate on the diff → docs + local commit. |
| `/plx:goal-spec` | Interview-locked goal planning for long-running efforts: a Socratic interview locks the goal (intent, binary success criteria, invariants, non-goals), then parallel read-only planner lanes design the how and Fable authors one self-contained spec into the build thread under `.project/builds/` — plus a paste-ready `/goal` condition. No code is written. |
| `/plx:review` | Multi-lane review, standalone: three parallel read-only lanes — correctness, cleanup, structural — synthesized by Fable as the integrating reviewer. Read-only; does not edit unless you explicitly ask for fixes. |

## Single-engine asks (raw passthrough — no review pipeline)

Adapts to intent: ask a question → it answers; ask for code → it edits; ask for a plan → it writes one.

| Command | Engine |
|---|---|
| `/plx:codex` | Codex (`plx-engine --engine codex --mode rw`) |
| `/plx:grok` | Grok (`plx-engine --engine grok --mode rw`) |

There is no `/plx:claude` — the orchestrator *is* Claude; just ask it directly.

## Setup

| Command | What it does |
|---|---|
| `/plx:init` | Bootstrap or repair a repo's agent-docs setup: classify the root `AGENTS.md` and create/rewrite/refresh it from repo evidence (Project Memory preserved byte-for-byte), mirror `CLAUDE.md` symlinks via `plx-link-claude`, and keep `.project/` git-ignored (agents populate it during real work). Root-only — nested `AGENTS.md` files are user-authored and untouched. Idempotent; say "dry run" to preview. |

## Notes

- Each command **is** its pipeline, written out in full: its `SKILL.md` carries the ordered steps, lane briefs, and engine invocations inline, resolving engine bindings from `config/parallax.yaml` and shared reference templates via `plx-skill --ref` (e.g. `dev/spec-template`, `init/AGENTS.template`).
- **No subagents.** Every lane is a `plx-engine` call the orchestrator makes itself, launched as background Bash with `--out`/`--log` files. Rubrics are injected by `--rubric` name from the plugin's `prompts/` directory.
- Engine bindings in `config/parallax.yaml` are defaults, not limits — the orchestrator may swap or add engines per `prompts/engines.md`.
