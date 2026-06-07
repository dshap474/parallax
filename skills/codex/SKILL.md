---
name: "plx::codex"
description: Single-engine passthrough — hand the task to Codex (headless). Answers, codes (with edits), or plans depending on what you ask. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:codex — single-engine passthrough (Codex)

Run the user's request through **Codex only** — no Parallax review pipeline, no other engines. Your job as orchestrator is to dispatch to Codex and return its output, not to re-do or review the work.

## Deterministic intake

!`${CLAUDE_PLUGIN_ROOT}/scripts/parallax-intake.sh`

## Execute

1. Treat the request as-is (question / coding / plan) — that only shapes the prompt you hand Codex.
2. Spawn `plx:codex-worker` so the TUI shows the Codex lane. Hand it: the repo path, the user's request as the prompt, and the exact command
   `${CLAUDE_PLUGIN_ROOT}/scripts/codex-rw.sh --repo <repo> --prompt <prompt> --out <out> --log <log>`
   (workspace-write: Codex edits when asked, and simply writes nothing for a pure question or plan).
3. Return Codex's output verbatim. Do not add your own review pass.

Request:

$ARGUMENTS
