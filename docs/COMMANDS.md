# Parallax command surface (`/plx:*`)

Every entry point lives under the `plx` plugin namespace. Stage skills let you drive an implementation stage-by-stage; `dev` strings them together; `goal-spec` preps autonomous runs.

## Stage skills

| Command | What it does |
|---|---|
| `/plx:plan` | Fable authors the plan itself (clarifying first only if needed), sizes an implementation/system red-team, folds the critiques, and delivers the final plan. In-context by default; persisted to `.project/builds/` only for multi-session efforts. No code written. |
| `/plx:build` | Writer lane(s) implement a plan — taken from a spec doc path, the plan already in the conversation, or a raw bounded task. One worker by default; parallel file-disjoint workers for large separable work. Verifies and reports; no review round. |
| `/plx:review` | Sized review round — 1 lane (small change) up to 3 dimensions × 2 engines (risky change) — then synthesis and **automatic fixes** via cheap targeted fix lanes (codex medium / grok). Genuinely uncertain findings go to the user as one batched question. Say "report only" to skip fixes. |

## Composition

| Command | What it does |
|---|---|
| `/plx:dev` | plan → build → review + fix → final gate, in one run, with per-stage sizing. For a trivial ask it skips the machinery entirely (direct edit or one cheap rw lane). Ends with a `.project/` docs pass per the repo's own rules. |
| `/plx:goal-spec` | Interview-locked goal planning for autonomous efforts: a Socratic interview locks the goal, a planner lane designs the how, parallel implementation/system critics red-team it, and Fable authors one self-contained `/goal`-ready spec into `.project/builds/` plus a paste-ready `/goal` condition. No code written. |

## Single-engine asks (raw passthrough — no pipeline)

Adapts to intent: ask a question → it answers; ask for code → it edits; ask for a plan → it writes one.

| Command | Engine |
|---|---|
| `/plx:codex` | Codex (`plx-engine --engine codex --mode rw`) |
| `/plx:grok` | Grok (`plx-engine --engine grok --mode rw`) |

There is no `/plx:claude` — the orchestrator *is* Claude; just ask it directly.

## Setup

| Command | What it does |
|---|---|
| `/plx:init` | Bootstrap or repair a repo's agent-docs setup: classify the root `AGENTS.md` and create/rewrite/refresh it from repo evidence (Project Memory preserved byte-for-byte), mirror `CLAUDE.md` symlinks via `plx-link-claude`, and keep `.project/` git-ignored. Root-only, idempotent; say "dry run" to preview. |

## Notes

- Each command **is** its pipeline, written out in full: its `SKILL.md` carries the ordered steps, lane briefs, and engine invocations inline, resolving engine bindings from `config/parallax.yaml` and shared reference templates via `plx-skill --ref`.
- **No subagents.** Every lane is a `plx-engine` call the orchestrator makes itself, launched as background Bash with `--out`/`--log` files. Rubrics are injected by `--rubric` name from the plugin's `prompts/` directory.
- **Sizing is declared up front.** Config bindings are the floor shape; the orchestrator sizes each run per `prompts/engines.md` (critics, workers, review lanes, effort, engines) and prints the chosen shape before launching — your veto point.
- **Skills never commit or publish.** Version control follows the target repo's own agent instructions.
