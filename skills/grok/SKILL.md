---
name: "plx::grok"
description: Single-engine passthrough — the orchestrator runs Grok (Composer, headless) directly via the write-capable wrapper. Answers, codes (with edits), or plans depending on what you ask. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:grok — single-engine passthrough (Grok Composer)

Run the user's request through **Grok only** — no Parallax review pipeline, no other engines, no subagent. You (the orchestrator) drive the engine wrapper yourself and return its output. Do not re-do or review the work.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>` and use it for every `--repo` flag below.
- If the worktree is dirty, read `git status --short` before the run — so you don't mistake pre-existing edits for Grok's.

## Execute

1. **Write the prompt.** Write the user's request verbatim to `<tmp>/prompt.md` in a fresh `mktemp -d` dir. The ask type (question / coding / plan) only shapes the prompt — the steps below are identical for all three.
2. **Run the wrapper yourself** via Bash — do not spawn any subagent. `plx-grok-rw` is on your PATH (shipped in the plugin's `bin/`); it runs one headless grok turn with safety pinned (kernel-enforced `workspace` sandbox + bypassPermissions) and emits only the model's final text. The write boundary is that kernel sandbox pinned inside the wrapper, scoped to `--repo` — writes outside it are OS-denied.

   ```
   plx-grok-rw --repo <repo> --prompt-file <tmp>/prompt.md --stdout
   ```

   Two caller rules from the wrapper's own help text:
   - **Disable the Claude Bash sandbox for this call** (`dangerouslyDisableSandbox: true` on the Bash invocation) — grok needs the network/keychain access the sandbox blocks. The kernel workspace sandbox still confines grok's writes.
   - **Trust the exit code, not stderr.** grok prints non-fatal `worker quit ... AuthorizationRequired` noise to stderr even on success — judge the run by its exit code.

   Plus:
   - The rw wrapper is used for **every** ask type: for a pure question or plan grok simply writes nothing (stated in the wrapper's own help text), so there is no separate read-only path here.
   - If the call may run long, use the Bash tool's `run_in_background` option rather than blocking.
   - Exit codes: **0** ok · **1** grok failure — a cancelled turn means no edits applied (surface the stderr/log excerpt to the user) · **2** usage error (your invocation is wrong — fix it) · **3** not signed in → tell the user to run `grok login` and stop.
3. **Return the result.** Emit grok's output verbatim — no review pass of your own. Then run `git -C <repo> status --short`: for a pure question/plan grok writes nothing; if files changed, add a diff summary (`git -C <repo> diff --stat`). Clean up the temp dir.

Request:

$ARGUMENTS
