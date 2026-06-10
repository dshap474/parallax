---
name: "plx::grok"
description: Single-engine passthrough — hand the task to Grok (Composer, headless). Answers, codes (with edits), or plans depending on what you ask. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:grok — single-engine passthrough (Grok Composer)

Run the user's request through **Grok only** — no Parallax review pipeline, no other engines. Your job as orchestrator is to dispatch to Grok and return its output, not to re-do or review the work.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>` and use it for every `--repo` flag and worker handoff below.
- If the worktree is dirty, read `git status --short` before editing — so you don't clobber unrelated user changes or mistake pre-existing edits for your own.

## Execute

1. Treat the request as-is (question / coding / plan) — that only shapes the prompt you hand Grok.
2. Write the user's request to a prompt file in a `mktemp -d` dir, then spawn `plx:grok-worker` (so the TUI shows the Grok lane) with the repo path and the prompt-file path. The worker drives Grok headless via the plugin's `plx-grok-rw` tool (kernel `workspace` sandbox: Grok edits within the repo when asked, and simply writes nothing for a pure question or plan); it knows to disable the Claude Bash sandbox for the call and to judge success by exit code.
3. Return Grok's output verbatim, plus the worker's diff summary if files changed (exit 3 from the tool means the user must run `grok login`). Do not add your own review pass. Clean up the temp dir.

Request:

$ARGUMENTS
