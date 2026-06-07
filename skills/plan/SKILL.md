---
name: "plx::plan"
description: "[SCAFFOLD] Solo planner (stage=plan, tier=solo). One planner produces a plan + per-task spec, no build, no review panel. Not yet implemented."
argument-hint: "<what to plan>"
disable-model-invocation: true
user-invocable: true
---

# /plx:plan — solo planner (SCAFFOLD)

**STATUS: scaffold — not yet implemented.**

Intended behavior: a single planner produces an implementation plan and a per-task coding spec for the request (Parallax Stage 1 only), then stops. No code is written and no review panel runs. Output a plan only.

Until implemented: tell the user this command is scaffolded, and offer the nearest built path — `/plx:claude "write a plan for …"` (single-engine plan) or `/plx:team-dev` (full build with review). Do **not** silently fall through to a build.

Request:

$ARGUMENTS
