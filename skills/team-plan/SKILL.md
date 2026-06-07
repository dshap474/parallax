---
name: "plx::team-plan"
description: "[SCAFFOLD] Team planner (stage=plan, tier=team). Multiple agents plan in parallel per parallax.yaml, then the orchestrator synthesizes one final plan. Not yet implemented."
argument-hint: "<what to plan>"
disable-model-invocation: true
user-invocable: true
---

# /plx:team-plan — team planner (SCAFFOLD)

**STATUS: scaffold — not yet implemented.**

Intended behavior: the planning engines configured for this command in `parallax.yaml` each produce an independent plan for the request (one lane per engine, read-only), then the orchestrator synthesizes them into a single final plan + per-task spec. No build, no code-review panel — this is the plan panel from `ultra` stopping at the synthesized plan.

Until implemented: tell the user it is scaffolded, and offer `/plx:team-dev` (build with review) or `/plx:claude "write a plan for …"`. Do **not** silently build.

Request:

$ARGUMENTS
