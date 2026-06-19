# Architecture

Parallax is a delegation-first coding workflow for Claude Code.

The public surface is three pipelines (each is a skill):

```text
dev | goal-spec | review
```

## Core idea

The orchestrator is the main Claude session — Fable, the most capable and most expensive model. Its value is **judgment**, and its context window is the scarcest resource in the system. So the prime directive:

> The orchestrator never holds bulk content it can delegate.

Subagent lanes burn the tokens — reading files, writing code, producing review transcripts — and hand back only the distilled artifact Fable needs for its next decision. Every skill is therefore a **context-routing policy**: what goes out, what comes back, in what compressed shape.

The model split makes this concrete: the orchestrator is Fable; subagent lanes run **Opus** (or drive Codex/Grok through the engine tools). Opus does bulk work cheaply; Fable's context only ever holds compact artifacts.

Fable does exactly two things itself: **plan authoring** (arbitrating across the Planning Briefs and writing the final plan doc) and the **final gate** (one fresh-eyes read of the diff after the worker's review round, fixing nits inline). Plan, build, and review are always delegated — and the review round itself is delegated one level further: the build worker spawns the read-only review lanes as nested subagents and fixes or rebuts every finding while its build context is still hot.

**Code with Opus, review with Codex** — the cross-model split is deliberate. A different model family reviewing the build gives genuinely independent scrutiny.

## The three atoms

Every behavior is a composition of three stage atoms, each a delegation pattern with a compact return contract:

| Atom | What it does | Who acts | Returns |
|---|---|---|---|
| `plan` | produce an implementation plan | Fable authors it; read-only lanes advise — a red-team critic in `dev`, parallel consultants in `goal-spec` | draft + critique (dev) / briefs (goal-spec) → final plan doc |
| `build` | execute a plan against the repo, then survive its own review round | exactly one writer worker, which spawns the review lanes and triages their findings | Buildout report (summaries + findings disposition, never code bodies) |
| `review` | independently review the work | parallel read-only review lanes; the caller triages | Findings → fixes (in `dev`) or a repair plan (standalone) |

Plan authoring and the final gate are always Fable and never delegated — that is where Fable-level intelligence is the product. Finding triage inside the build's review round belongs to the build worker, which wrote the code and can check each claim directly.

## The dev pipeline — 7 steps

`dev` is the flagship composition: **plan → build+review → final gate → docs**.

1. **Fable authors the plan.** Reads the repo (scoped to what the design needs), settles the approach, and writes the plan doc itself to the shared spec template — outcome-first: intent, success criteria, invariants, suggested path, validation.
2. **One cross-model red-team critic.** Fable hands a Codex critic (`codex-plan-critic`, high) the repo path and the draft plan. It stress-tests the plan against the repo — wrong facts, spec drift, missed work, a materially simpler design, unhandled edges, risk — and returns a critique (findings), never a rewrite. The rubric lives inside the agent.
3. **Fable folds the critique.** Triages every finding — adopts it or rebuts it with a reason, verifying load-bearing claims itself — then finalizes the plan. Escape hatch: a fundamental objection → re-draft.
4. **Delegate the build with its review round.** Fable hands one Opus worker (`claude-worker`) the final plan spec plus the reviewer persona names resolved from the config. The worker implements, self-verifies, **spawns the two Codex-xhigh review lanes itself** — nested read-only subagents, in parallel, each handed a neutral review brief (the debug lane covers spec match, bugs, robustness, and failure paths; the simplify lane covers over-engineering and structure) — then triages every finding with its build context still hot: fix it or rebut it with evidence, never silently drop it. One round, hard cap; then it re-verifies.
5. **Buildout report returns.** Every file touched, per-file summary of what changed and why, coding decisions, verification, and the disposition of every review finding (fixed / rebutted / residual). Summaries and pointers only, never code bodies or diffs.
6. **Fable gates the work.** Now — and only now — it reads the diff once, with fresh eyes: do the rebuttals hold, do the residuals matter, did the worker and both lanes miss something? By this point the cheap mistakes are caught; Fable's judgment goes on what's left. It fixes nits inline, then re-runs the plan's verification commands. (Escape hatch: structural rework → a fresh spec back through the build.)
7. **Docs + commit.** A docs subagent updates documentation, then a **local commit only** — never a push, PR, or publish.

The pipeline has exactly **three top-level subagent spawns** (1 plan-critic + 1 builder + 1 docs); the builder spawns the 2 review lanes nested inside its own context, so findings traffic never touches Fable's window.

## Pipelines

| Pipeline (skill) | Config key | Purpose | Steps |
|---|---|---|---|
| `dev` | `dev` | build a change end to end | 1–7 |
| `goal-spec` | `goal-spec` | interview-locked goal planning, no edits | standalone (read-only) |
| `review` | `review` | audit / debug / critique without edits | standalone (read-only) |

Explicit `/plx:*` commands run one of these three (see [`COMMANDS.md`](COMMANDS.md)). The single-engine passthroughs `/plx:codex` and `/plx:grok` run a task through one engine with no review pipeline.

**Disabled / parked:** the `team-*` and `ultra-*` skills have their `SKILL.md` renamed to `DISABLED.md`. When revived they are regenerated from `.project/VISION.md` — the same dev skeleton with more engines in the read stages (e.g. ultra adds Grok lanes and a plan-review stage).

## Rubrics live in the agents

Any prompt text that is the same every run — review dimension rubrics, the plan-quality rubric, the Finding Schema, output templates — is baked into the **agent files**, alongside each engine agent's operator manual for the `plx-*` tools. The orchestrator's spawn message carries only what changes per task: repo path + task-specific brief. Fable hands each subagent **the work, not the command**.

## Safety model

- Plan-critic, planner, and review lanes are read-only for every engine. There is exactly **one writer at a time, always**: the build worker (its nested reviewer subagents are read-only lanes), plus Fable fixing nits at the final gate.
- The build worker spawns only the reviewer personas the orchestrator names in its dispatch — never the plan-critic, planners, other workers, or docs agents. (The frontmatter `Agent(...)` allowlist documents this; the binding rule lives in the persona prose.)
- Codex/Grok review, plan, and plan-critic calls go through `bin/plx-codex-ro` / `bin/plx-grok-ro` (read-only).
- A non-Claude writer (when `config/parallax.yaml` binds `code: codex`/`grok`) goes through `bin/plx-codex-rw` (scoped `workspace-write`) / `bin/plx-grok-rw` (kernel `workspace` sandbox) — edits confined to the target repo. The default config keeps Claude the sole writer.
- Engine wrappers never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, or `--yolo`.
- Neutral context: lanes get the spec or brief, never the caller's analysis or another lane's output.
- Fable never reads built code before the final gate — and at the gate only the diff, once.
- Parallax does not create `.parallax/`, `.parallax/cache`, or `.parallax/runs` in target repos. Runtime prompts, logs, and engine outputs are chat context or temp files cleaned up before commands return.
- Every dev run ends with a docs subagent and a local commit — never a push, PR, or publish step.

## Hooks policy

Parallax v0.1 installs no hooks. Safety comes from: one public `plx` router, a deterministic engine API (`bin/plx-*`) with uniform flags, uniform exit codes (0 ok · 1 engine failure · 2 usage error · 3 auth needed), `--help` manuals, and safety flags pinned in code; read-only review/plan invocations; scoped-write tools for an opt-in non-Claude writer; and no repo-local runtime state.
