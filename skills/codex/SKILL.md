---
name: "plx::codex"
description: Single-engine passthrough — the orchestrator runs Codex (headless) directly via the write-capable wrapper. Answers, codes (with edits), or plans depending on what you ask. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:codex — single-engine passthrough (Codex)

Run the user's request through **Codex only** — no Parallax review pipeline, no other engines, no subagent. You (the orchestrator) drive the engine wrapper yourself and return its output. Do not re-do or review the work.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>` and use it for every `--repo` flag below.
- If the worktree is dirty, read `git status --short` before the run — so you don't mistake pre-existing edits for Codex's.

## Execute

1. **Write the prompt.** Write the user's request verbatim to `<tmp>/prompt.md` in a fresh `mktemp -d` dir. The ask type (question / coding / plan) only shapes the prompt — the steps below are identical for all three.
2. **Run the wrapper yourself** via Bash — do not spawn any subagent. `plx-codex-rw` is on your PATH (shipped in the plugin's `bin/`); it runs one headless `codex exec` turn with safety pinned (workspace-write sandbox scoped to `--repo`, `--ignore-user-config`, `--ephemeral`) and prints only Codex's final message. The write boundary is that kernel/CLI sandbox pinned inside the wrapper, scoped to `--repo` — nothing else can be touched.

   ```
   plx-codex-rw --repo <repo> --prompt-file <tmp>/prompt.md --stdout
   ```

   - The rw wrapper is used for **every** ask type: for a pure question or plan Codex simply writes nothing (stated in the wrapper's own help text), so there is no separate read-only path here.
   - Default effort is `high`; add `--effort xhigh` for a genuinely hard ask.
   - If the call may run long, use the Bash tool's `run_in_background` option rather than blocking.
   - Exit codes: **0** ok · **1** Codex failure (surface the stderr/log excerpt to the user) · **2** usage error (your invocation is wrong — fix it) · **3** not signed in → tell the user to run `codex login` and stop.
3. **Return the result.** Emit Codex's output verbatim — no review pass of your own. Then run `git -C <repo> status --short`: for a pure question/plan Codex writes nothing; if files changed, add a diff summary (`git -C <repo> diff --stat`). Clean up the temp dir.

Request:

$ARGUMENTS
