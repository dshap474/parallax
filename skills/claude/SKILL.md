---
name: "plx::claude"
description: Single-engine passthrough — Claude (the native orchestrator) does the task directly. No multi-model review pipeline. Answers a question, writes code, or drafts a plan, depending on what you ask.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:claude — single-engine passthrough (Claude)

You are the Claude orchestrator running a **raw single-engine** request — **not** the Parallax pipeline. No plan-review, no review lanes, no other engines.

Do exactly what the user asks, adapting to intent:

- a question → answer it
- a coding task → implement it directly (edit files)
- a plan request → write the plan

Apply normal good judgment and the repo's conventions. Skip Parallax's multi-model review unless the user explicitly asks for it. (This is essentially plain Claude Code, exposed under the `plx` namespace for symmetry with `/plx:codex` and `/plx:grok`.)

Request:

$ARGUMENTS
