---
name: "plx::codex"
description: Single-engine passthrough — the orchestrator runs Codex headless with read-only access for questions/plans and write access only for explicit implementation requests. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:codex — single-engine passthrough (Codex)

Run the user's request through **Codex only** — no Parallax review pipeline, no other engines. You (the orchestrator) drive the engine wrapper yourself and return its output. Do not re-do or review the work.

## Execute

Three tool calls — no subagent.

1. **One Bash call** to set up: `git rev-parse --show-toplevel && git status --short && mktemp -d`. The first line is `<repo>` (the wrapper needs an absolute `--repo`, and that path is the write boundary); the status snapshot is so pre-existing edits aren't later attributed to Codex; the last line is `<tmp>`.
2. **One Write call** to write `<tmp>/prompt.md` as a self-contained brief — Codex runs headless and fresh, seeing only this file plus the repo it reads itself, never your conversation. Lead with the user's request verbatim. Add a short `## Context` heading **only if** the ask leans on the conversation ("ok build this", "use the approach we discussed") — the minimum it needs: decisions already made, stated constraints, specific files/paths discussed. Terse bullets, no transcript dumps; carry conversation-held facts only, not repo facts (Codex reads the repo). No analysis, opinions, or proposed solution of your own — context, not coaching; the passthrough's point is Codex's take. A self-contained ask needs no `## Context`.
   Choose `<mode>` from the request: questions, audits, investigations, reviews, and plans use `ro`; only an explicit implementation or edit request uses `rw`. When context says "don't code yet" or equivalent, use `ro`.
3. **One Bash call** to run, check, and clean up in a single `;`-chained command (so status/cleanup run even on engine failure):

   ```
   plx-engine --engine codex --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --effort <medium|high|xhigh> --stdout; rc=$?; echo ---; git -C <repo> status --short; rm -rf <tmp>; (exit $rc)
   ```

   `plx-engine` is on your PATH (shipped in the plugin's `bin/`); it runs one headless `codex exec` turn with safety pinned (`read-only` or repo-scoped `workspace-write`, `--ignore-user-config`, `--ephemeral`) and prints only Codex's final message.

   - Effort: `--effort medium` by default. Use `high` or `xhigh` only when concrete
     complexity or risk warrants it: cross-file contracts, concurrency, data integrity,
     money paths, or a wide refactor. Pick one — always pass the flag.
   - If the call may run long, use the Bash tool's `run_in_background` option rather than blocking (the post-run status/diff then happens after the completion notification).
   - Exit codes: **0** ok · **1** Codex failure (surface the stderr/log excerpt to the user) · **2** usage error (your invocation is wrong — fix it) · **3** not signed in → tell the user to run `codex login` and stop.

   Then emit Codex's output verbatim — no review pass of your own. Only if the status shows new changes vs the step-1 snapshot, add a summary (`git -C <repo> diff --stat`).

Request:

$ARGUMENTS
