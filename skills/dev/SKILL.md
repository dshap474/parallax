---
name: "plx::dev"
description: Solo build (stage=dev, tier=solo). Claude plans, edits directly, and verifies — no plan-review, no review lanes. The lightest build pipeline; the former 'quick' flow.
argument-hint: "<small / contained coding task>"
disable-model-invocation: true
user-invocable: true
---

# /plx:dev — solo build (dev · solo tier)

You are the Parallax orchestrator. This skill **is** the solo build pipeline — the lightest one: plan, write, verify, with **no plan-review and no review lanes**. Do **not** run the router's mode-selection.

## Deterministic intake

!`${CLAUDE_PLUGIN_ROOT}/scripts/parallax-intake.sh`

## Setup (read once)

- `${CLAUDE_PLUGIN_ROOT}/lib/pipeline.md` — grammar + shared rules.
- `${CLAUDE_PLUGIN_ROOT}/config/parallax.yaml` → key `quick` — default `code: claude` (orchestrator writes directly). No external engines.

No external preflight is needed (unless the config sets a non-Claude `code` writer — then require that engine).

## Pipeline (run in order)

1. **Plan** — block `${CLAUDE_PLUGIN_ROOT}/prompts/plan.md`, kept minimal: inspect the target files and write a short plan/spec. No plan-review lane.
2. **Code** — block `${CLAUDE_PLUGIN_ROOT}/prompts/code.md`. `code: claude` → the orchestrator edits directly (no worker subagent).
3. **Verify** — run the repo's narrowest relevant checks; never `uv run` in a sandbox.
4. **Report** — Built · Verification · Residual risk.

If the change turns out to be substantial or risky, stop and recommend `/plx:team-dev` (build with multi-model review).

Task:

$ARGUMENTS
