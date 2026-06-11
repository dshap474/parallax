---
name: "plx::grok"
description: Single-engine passthrough — the orchestrator runs Grok (Composer, headless) directly via the write-capable wrapper. Answers, codes (with edits), or plans depending on what you ask. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:grok — single-engine passthrough (Grok Composer)

Run the user's request through **Grok only** — no Parallax review pipeline, no other engines, no subagent. You (the orchestrator) drive the engine wrapper yourself and return its output. Do not re-do or review the work.

## Execute

Three tool calls — no subagent.

1. **One Bash call** to set up: `git rev-parse --show-toplevel && git status --short && mktemp -d`. The first line is `<repo>` (the wrapper needs an absolute `--repo`, and that path is the write boundary); the status snapshot is so pre-existing edits aren't later attributed to Grok; the last line is `<tmp>`.
2. **One Write call** to make `<tmp>/prompt.md` a self-contained brief — grok runs headless and fresh, seeing only this file plus the repo it reads itself, never your conversation. Lead with the user's request verbatim. Then, only if the ask leans on conversation context ("ok build this", "use the approach we discussed"), add a short `## Context` heading carrying the minimum it needs to finish: decisions already made, stated constraints, specific files/paths discussed. Calibrate hard — terse bullets, anything that could matter and nothing else, no transcript dumps. Don't restate repo facts (grok reads the repo); only carry conversation-held facts. Forbid your own analysis, opinions, or proposed solution — context, not coaching; the point of the passthrough is grok's take. A self-contained ask needs no `## Context` at all. The ask type (question / coding / plan) only shapes the prompt — the steps are identical for all three.
3. **One Bash call** to run, check, and clean up in a single `;`-chained command (so status/cleanup run even on engine failure):

   ```
   plx-grok-rw --repo <repo> --prompt-file <tmp>/prompt.md --stdout; rc=$?; echo ---; git -C <repo> status --short; rm -rf <tmp>; (exit $rc)
   ```

   `plx-grok-rw` is on your PATH (shipped in the plugin's `bin/`); it runs one headless grok turn with safety pinned (kernel-enforced `workspace` sandbox + bypassPermissions) and emits only the model's final text — the write boundary is that sandbox scoped to `--repo`, writes outside it are OS-denied. The rw wrapper is used for **every** ask type; for a pure question or plan grok simply writes nothing, so there is no separate read-only path.

   Two caller rules from the wrapper's own help text:
   - **Disable the Claude Bash sandbox for this call** (`dangerouslyDisableSandbox: true` on the Bash invocation) — grok needs the network/keychain access the sandbox blocks. The kernel workspace sandbox still confines grok's writes.
   - **Trust the exit code, not stderr.** grok prints non-fatal `worker quit ... AuthorizationRequired` noise to stderr even on success — judge the run by its exit code.

   - If the call may run long, use the Bash tool's `run_in_background` option rather than blocking (the post-run status/diff then happens after the completion notification).
   - Exit codes: **0** ok · **1** grok failure — a cancelled turn means no edits applied (surface the stderr/log excerpt to the user) · **2** usage error (your invocation is wrong — fix it) · **3** not signed in → tell the user to run `grok login` and stop.

   Then emit grok's output verbatim — no review pass of your own. Only if the status shows new changes vs the step-1 snapshot, add a summary (`git -C <repo> diff --stat`).

Request:

$ARGUMENTS
