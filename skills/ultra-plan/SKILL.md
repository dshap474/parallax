---
name: "plx::ultra-plan"
description: "[SCAFFOLD] Ultra planner (stage=plan, tier=ultra). Multi-stage planner with a Socratic clarifying interview before producing a staged plan. Not yet implemented."
argument-hint: "<what to plan>"
disable-model-invocation: true
user-invocable: true
---

# /plx:ultra-plan — ultra planner (SCAFFOLD)

**STATUS: scaffold — not yet implemented.**

Intended behavior: a multi-stage planning flow that begins with a **Socratic interview** — the orchestrator asks the user clarifying questions until scope, constraints, and acceptance are pinned — then runs a multi-engine plan panel and synthesizes a staged, milestone-broken plan with per-task specs. No build.

Until implemented: tell the user it is scaffolded, and offer `/plx:ultra-dev` (full build) or `/plx:claude` for an ad-hoc plan. Do **not** silently build.

Request:

$ARGUMENTS
