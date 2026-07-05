# Parallax

Multi-model coding-agent orchestration for Claude Code — as a **toolbox, not a script**.

The orchestrator is Claude (Fable). It drives three coding engines — **Codex, Grok, and Claude itself** — headless, directly, through one wrapper (`plx-engine`). There are no subagents: evals showed operator subagents only add wall-clock time. What survives from them is the part that mattered — the lane rubrics, now shipped in [`prompts/`](prompts/) and injected at runtime by name. The orchestrator gets tools plus a judgment doc ([`prompts/engines.md`](prompts/engines.md)) and decides which engine does which work; the shipped config is **defaults, not limits**.

The default posture is **cross-engine review**: review work with a different engine than the one that wrote it — independence catches what self-review can't.

Explicit `/plx:*` commands run a pipeline (`dev`, `goal-spec`, `review`), hand a task to a single engine (`codex`, `grok`), or bootstrap a repo's agent-docs setup (`init`) — see [`docs/COMMANDS.md`](docs/COMMANDS.md). Default engine bindings live in [`config/parallax.yaml`](config/parallax.yaml).

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

Each pipeline establishes repo ground truth (Bootstrap), then runs its steps. Each pipeline is a fully self-contained skill — steps, lane briefs, and engine invocations written out inline in its own `SKILL.md`. Every lane is one `plx-engine` call the orchestrator makes itself, launched as **background Bash** (engine turns can outrun the 10-minute foreground cap) with results landing in temp out-files it reads selectively.

| Pipeline | Use case | Lanes |
|---|---|---|
| `dev` | build a change end to end (plan → red-team → build → review + fix → final gate → docs + local commit) | Fable authors the plan; 1 read-only plan-critic lane; 1 writer lane; 3 parallel read-only review lanes; Fable synthesizes, fixes, gates |
| `goal-spec` | lock a goal, then plan it (no edits) | interview + parallel read-only planner lanes |
| `review` | audit / debug / critique without edits | 3 parallel read-only review lanes (correctness, cleanup, structural) |

`goal-spec` runs a Socratic interview to lock a goal, then multi-model planning, and writes one self-contained, `/goal`-ready spec into a build thread under `.project/builds/`; `review` is the review stage run standalone. `/plx:codex` and `/plx:grok` hand a task straight to one engine with no pipeline.

Plan-critic, planner, and review lanes are always `--mode ro`. There is exactly **one writer at a time** — the rw writer lane, plus Fable fixing nits at synthesis and the final gate. Parallax writes no repo-local runtime state; prompt/output files live in shell temp directories only.

### The dev pipeline

1. Fable authors the plan itself — reads the repo, settles the approach, writes the spec to the shared template.
2. A cross-engine red-team critic lane (`--rubric plan-critic`, read-only) stress-tests the draft against the repo and returns findings, never a rewrite.
3. Fable folds the critique — adopts or rebuts each finding, verifying load-bearing claims itself — then finalizes the plan.
4. One writer lane (`--rubric worker --mode rw`, Claude by default) implements, self-verifies with the repo's own checks, and returns a Buildout report — summaries, never code bodies.
5. Fable runs the review round itself: one neutral brief, three parallel read-only lanes (correctness, cleanup, structural) on engines that didn't write the code, then synthesis — dedup, verify-before-trusting, kill false positives. It fixes small survivors directly or sends one fix turn back through the writer engine.
6. The final gate: Fable reads the diff once with fresh eyes, fixes nits, re-runs verification.
7. Docs update + a **local commit** — never a push or PR.

### Choosing engines

`config/parallax.yaml` binds each pipeline role to an engine (`code` takes one engine; critic/planner/review roles take lists). These are starting points — [`prompts/engines.md`](prompts/engines.md) carries the judgment for when to swap, add a second reviewer, or escalate effort. Plan authoring, review synthesis, and the final gate are always the orchestrator.

## Requirements

Parallax orchestrates external model CLIs you install and authenticate yourself. It does not bundle, host, or proxy any model.

| Engine | Install | Used by default |
|---|---|---|
| Codex | `codex` CLI + auth | plan-critic, planner, and review lanes; `/plx:codex` |
| Grok | `grok` CLI + auth | `/plx:grok`; optional second-perspective lanes |
| Claude | `claude` CLI (already present — it runs the session) | the writer lane (`code: claude`); any lane you bind it to |

The shipped `dev`/`goal-spec`/`review` configs need Codex. See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Architecture

Three stage atoms — `plan`, `build`, `review` — compose into the pipelines. The safety model: every lane goes through `plx-engine`, which pins safety per engine in code — Codex config-isolated and sandboxed (`read-only` / `workspace-write`), Grok kernel-sandboxed (Seatbelt/Landlock), Claude headless with scoped permission modes and tool allowlists. Wrappers never use `danger-full-access` / `--yolo` / bypass flags, and skills never hand-construct raw engine commands. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repo layout

```text
parallax/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/       # one dir per command; each SKILL.md is fully self-contained
├── prompts/      # lane rubrics (injected via plx-engine --rubric) + engines.md judgment doc
├── config/       # parallax.yaml — default engine bindings (dev, goal-spec, review)
├── bin/          # engine API on PATH (plx-engine, plx-preflight, plx-config, plx-skill, plx-link-claude)
└── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
```

Each `skills/<name>/SKILL.md` carries its pipeline inline — no `${CLAUDE_PLUGIN_ROOT}`, no path pointers, no script injection. Skills reference rubrics by bare `--rubric` name and shared templates via `plx-skill --ref`; both resolve inside the `bin/` tools, so the skills stay self-contained.

## Status

v0.2.0

## License

MIT — see [`LICENSE`](LICENSE).
