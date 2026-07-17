---
name: grok
description: Single-engine passthrough — the orchestrator runs Grok 4.5 headless at medium effort by default, read-only for questions/plans and write-capable only for explicit implementation requests. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
---

# $plx:grok — single-engine passthrough (Grok 4.5)

Run the user's request through **Grok only** — no Parallax review pipeline, no other engines, no subagent. You (the orchestrator) drive the engine wrapper yourself and return its output. Do not re-do or review the work.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/grok/SKILL.md`; invoke the packaged wrapper at `<plugin-root>/bin/plx-engine`.

## Execute

Three tool calls — no subagent.

1. **One shell call** to set up: `git rev-parse --show-toplevel && git status --short && mktemp -d`. The first line is `<repo>` (the wrapper needs an absolute `--repo`, and that path is the write boundary); the status snapshot is so pre-existing edits aren't later attributed to Grok; the last line is `<tmp>`.
2. **One file edit** to write `<tmp>/prompt.md` as a self-contained brief — grok runs headless and fresh, seeing only this file plus the repo it reads itself, never your conversation. Lead with the user's request verbatim. Add a short `## Context` heading **only if** the ask leans on the conversation ("ok build this", "use the approach we discussed") — the minimum it needs: decisions already made, stated constraints, specific files/paths discussed. Terse bullets, no transcript dumps; carry conversation-held facts only, not repo facts (grok reads the repo). No analysis, opinions, or proposed solution of your own — context, not coaching; the passthrough's point is grok's take. A self-contained ask needs no `## Context`.
   Choose `<mode>` from the request: questions, audits, investigations, reviews, and plans use `ro`; only an explicit implementation or edit request uses `rw`. When context says "don't code yet" or equivalent, use `ro`.
3. **One shell call** to run, check, and clean up in a single `;`-chained command (so status/cleanup run even on engine failure):

   ```
   <plugin-root>/bin/plx-engine --engine grok --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --stdout; rc=$?; echo ---; git -C <repo> status --short; rm -rf <tmp>; (exit $rc)
   ```

   `<plugin-root>/bin/plx-engine` is packaged with this skill (shipped in the plugin's `bin/`); it runs one headless Grok 4.5 turn at `medium` effort by default with safety pinned (kernel-enforced `read-only` or repo-scoped `workspace` sandbox + bypassPermissions) and emits only the model's final text.

   Two caller rules from the wrapper's own help text:
   - If Grok cannot reach its network or keychain under the host sandbox, request narrowly
     scoped approval for this wrapper invocation. Grok's kernel workspace sandbox still
     confines its writes.
   - **Trust the exit code, not stderr.** grok prints non-fatal `worker quit ... AuthorizationRequired` noise to stderr even on success — judge the run by its exit code.

   - If the call may run long, use a retained execution session and poll it; run status
     and cleanup after completion.
   - Exit codes: **0** ok · **1** grok failure — a cancelled turn means no edits applied (surface the stderr/log excerpt to the user) · **2** usage error (your invocation is wrong — fix it) · **3** not signed in → tell the user to run `grok login` and stop.

   Then emit grok's output verbatim — no review pass of your own. Only if the status shows new changes vs the step-1 snapshot, add a summary (`git -C <repo> diff --stat`).

Request:

$ARGUMENTS
