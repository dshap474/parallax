---
name: "plx::team-dev"
description: Force Parallax TEAM build (stage=dev, tier=team). Skips routing. Claude writes directly; Codex + Claude read-only review lanes per config/parallax.yaml. For substantial builds/refactors that want multi-model review.
argument-hint: "<coding task / build / refactor>"
disable-model-invocation: true
user-invocable: true
---

# /plx:team-dev — team build (dev · team tier)

You are the Parallax orchestrator. This skill **is** the team build pipeline — an ordered composition of prompt blocks. Do **not** run the router's mode-selection.

## Deterministic intake

!`${CLAUDE_PLUGIN_ROOT}/scripts/parallax-intake.sh`

## Setup (read once, before Stage 1)

- `${CLAUDE_PLUGIN_ROOT}/lib/pipeline.md` — pipeline grammar: engine binding, subagent injection, neutral-context rule, shared rules. **Honor every shared rule.**
- `${CLAUDE_PLUGIN_ROOT}/lib/engines.md` — how to invoke each engine.
- `${CLAUDE_PLUGIN_ROOT}/config/parallax.yaml` → key `team` — resolve each role's engine. Defaults:
  - `plan-review: [codex]` · `code: claude` · `review-debug: [codex, claude]` · `review-correctness: [codex]`

Run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh --repo <repo> --require-codex` before Stage 1. If Codex is unavailable, stop with a clear message — team requires it.

## Pipeline (run in order)

Each step plugs in a prompt block. Resolve its engine from the config above and spawn the lane as a named subagent per `lib/pipeline.md` → "Engine binding & subagent injection". Review/plan lanes are read-only and get **neutral context only**.

1. **Plan** — block `${CLAUDE_PLUGIN_ROOT}/prompts/plan.md`. Orchestrator writes the plan + a per-task spec (`${CLAUDE_PLUGIN_ROOT}/prompts/coding-spec-template.md`) for each unit of work.
2. **Plan-review** — block `${CLAUDE_PLUGIN_ROOT}/prompts/correctness.md` against the *plan* → `plx:codex-reviewer` (read-only). Build the prompt with `scripts/make-review-prompt.sh`.
3. **Reconcile** — fold valid notes into the specs; spend a revise turn only on Critical/High (or a material gap you agree with).
4. **Code** — block `${CLAUDE_PLUGIN_ROOT}/prompts/code.md`. `code: claude` in team → the **orchestrator writes directly** (no worker subagent).
5. **Refine** — block `${CLAUDE_PLUGIN_ROOT}/prompts/refine.md`, applied directly. End with the **Structural Verdict** (`none` if clean).
6. **Review** — run both lanes in a single turn, neutral context, on the review pack (request + final spec + edited files + git diff):
   - debug — block `${CLAUDE_PLUGIN_ROOT}/prompts/debug.md` → `plx:codex-reviewer` + `plx:claude-reviewer`
   - correctness — block `${CLAUDE_PLUGIN_ROOT}/prompts/correctness.md` → `plx:codex-reviewer`
7. **Fix** — block `${CLAUDE_PLUGIN_ROOT}/prompts/synthesis.md`. Orchestrator runs the Ordered Synthesis and applies fixes directly, in one coherent pass.
8. **Verify** — run the repo's narrowest existing checks (`.venv/bin/ruff`, `.venv/bin/pytest`, npm/cargo/go…). Never `uv run` in a sandbox.
9. **Report** — Built · Plan changes · Refine (+ Structural Verdict) · Review findings (accepted/rejected, severity-ranked) · Fixes applied · Verification · Residual risk.

Task:

$ARGUMENTS
