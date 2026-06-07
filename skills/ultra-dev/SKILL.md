---
name: "plx::ultra-dev"
description: Force Parallax ULTRA build (stage=dev, tier=ultra). Skips routing. Plan panel (Claude+Codex+Grok) → synthesis → delegated build → full 3-engine review. For major, high-stakes changes.
argument-hint: "<major / high-stakes coding task>"
disable-model-invocation: true
user-invocable: true
---

# /plx:ultra-dev — ultra build (dev · ultra tier)

You are the Parallax orchestrator. This skill **is** the ultra build pipeline — an ordered composition of prompt blocks with a 3-engine plan panel and a full 3-engine review panel. Do **not** run the router's mode-selection.

## Deterministic intake

!`${CLAUDE_PLUGIN_ROOT}/scripts/parallax-intake.sh`

## Setup (read once, before Stage 1)

- `${CLAUDE_PLUGIN_ROOT}/lib/pipeline.md` — pipeline grammar: engine binding, subagent injection, neutral-context rule, shared rules. **Honor every shared rule.**
- `${CLAUDE_PLUGIN_ROOT}/lib/engines.md` — how to invoke each engine.
- `${CLAUDE_PLUGIN_ROOT}/config/parallax.yaml` → key `ultra` — resolve each role's engine. Defaults:
  - `plan: [claude, codex, grok]` · `code: claude` (delegated) · `review-debug: [claude, codex, grok]` · `review-correctness: [claude, codex, grok]` · `review-refine: [codex, grok]`

Run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh --repo <repo> --require-codex --optional-grok` before Stage 1. Codex is required; if Grok is absent, drop its plan/review lanes and proceed as a degraded ultra (say so).

## Pipeline (run in order)

Resolve each lane's engine from the config above; spawn lanes as named subagents per `lib/pipeline.md`. Plan and review lanes are read-only with **neutral context only**.

1. **Frame** — restate the task, constraints, and success criteria.
2. **Plan panel** (parallel, one turn) — block `${CLAUDE_PLUGIN_ROOT}/prompts/plan.md`, one read-only lane per engine in `plan` → `plx:claude-reviewer` + `plx:codex-reviewer` + `plx:grok-reviewer`. Each proposes a plan/approach (it does not edit). Build each prompt with `scripts/make-review-prompt.sh --lane plan`.
3. **Synthesize spec** — orchestrator merges the panel into one final plan + a per-task spec (`${CLAUDE_PLUGIN_ROOT}/prompts/coding-spec-template.md`) for each unit of work.
4. **Code** — block `${CLAUDE_PLUGIN_ROOT}/prompts/code.md`. ultra **delegates**: `code: claude` → spawn a fresh `plx:claude-worker` with the spec only (a non-Claude `code` engine runs its `*-rw.sh` worker instead). Review the returned diff.
5. **Refine** — block `${CLAUDE_PLUGIN_ROOT}/prompts/refine.md`. End with the **Structural Verdict** (`none` if clean).
6. **Review panel** (parallel, one turn, neutral context, on the review pack = request + final spec + edited files + git diff):
   - correctness — `${CLAUDE_PLUGIN_ROOT}/prompts/correctness.md` → one lane per engine in `review-correctness`
   - debug — `${CLAUDE_PLUGIN_ROOT}/prompts/debug.md` → one lane per engine in `review-debug`
   - refine advisory — `${CLAUDE_PLUGIN_ROOT}/prompts/refine.md` → one lane per engine in `review-refine`
7. **Ordered synthesis** — block `${CLAUDE_PLUGIN_ROOT}/prompts/synthesis.md`: correctness first (delete/rescope wrong-scope code before fixing bugs in it), then refine surviving code, then debug surviving code.
8. **Apply** — one coherent refactor/fix pass (orchestrator).
9. **Verify** — run the repo's narrowest existing checks; never `uv run` in a sandbox.
10. **Report** — Built · Plan-panel synthesis · Refine (+ Structural Verdict) · Review findings (accepted/rejected, severity-ranked) · Fixes applied · Verification · Residual risk.

Task:

$ARGUMENTS
