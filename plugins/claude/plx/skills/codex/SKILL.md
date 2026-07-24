---
name: codex
description: Single-engine passthrough — the orchestrator runs Codex headless with read-only access for questions/plans and write access only for explicit implementation requests. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:codex — single-engine passthrough (Codex)

Run the user's request through **Codex only** — no Parallax review pipeline, no other engines. You (the orchestrator) drive the engine wrapper yourself and return its output. Do not re-do or review the work.

## Resolve launch settings

Resolve the model and effort from the user's request before writing the brief:

- Defaults: `model=gpt-5.6-sol`, `effort=medium`. Use `high` or `xhigh` instead
  only when concrete complexity or risk warrants it.
- An explicit user model or effort always replaces that setting's default. Natural
  wording is enough: `ask gpt-5.6-terra low for <task>`, `use gpt-5.6-sol at
  xhigh`, and `model=gpt-5.6-sol effort=medium` all set real launch flags.
- Treat `reasoning`, `reasoning level`, and `effort` as names for the same launch
  setting.
- Do not infer an override from model names discussed only as task content. Do not
  normalize, forbid, or silently replace an explicit value. If Codex rejects it,
  surface that error.

Always pass both resolved values as `--model <model> --effort <effort>`, including
on the persistent path.

## Choose the thread mode

Default to the existing **ephemeral** `plx-engine` path below. Choose a persistent
app-server thread only when the user explicitly wants future continuation or when you
reasonably expect multiple later `/plx:codex` turns and repository rediscovery would be
material. Complexity alone is not a reason to persist.

Before starting a persistent thread, say `Persistent Codex thread: yes — <reason>`.
Resume only when the user supplies a thread ID or the current conversation contains one
unambiguous ID previously returned by this skill. Persistent threads are only for this
passthrough — never use them for Parallax plan critics, goal specs, dev runs, or code
review lanes. There is no hidden current-thread registry.

## Execute

Three tool calls — no subagent.

1. **One Bash call** to set up: `git rev-parse --show-toplevel && git status --short && mktemp -d`. The first line is `<repo>` (the wrapper needs an absolute `--repo`, and that path is the write boundary); the status snapshot is so pre-existing edits aren't later attributed to Codex; the last line is `<tmp>`.
2. **One Write call** to write `<tmp>/prompt.md` as a self-contained brief — Codex runs headless and fresh, seeing only this file plus the repo it reads itself, never your conversation. Lead with the user's request verbatim. Add a short `## Context` heading **only if** the ask leans on the conversation ("ok build this", "use the approach we discussed") — the minimum it needs: decisions already made, stated constraints, specific files/paths discussed. Terse bullets, no transcript dumps; carry conversation-held facts only, not repo facts (Codex reads the repo). No analysis, opinions, or proposed solution of your own — context, not coaching; the passthrough's point is Codex's take. A self-contained ask needs no `## Context`.
   Choose `<mode>` from the request: questions, audits, investigations, reviews, and plans use `ro`; only an explicit implementation or edit request uses `rw`. When context says "don't code yet" or equivalent, use `ro`.
3. **One Bash call** to run, check, and clean up in a single `;`-chained command (so status/cleanup run even on engine failure). Choose exactly one path:

   **Ephemeral default:**

   ```
   plx-engine --engine codex --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort> --stdout; rc=$?; echo ---; git -C <repo> status --short; rm -rf <tmp>; (exit $rc)
   ```

   `plx-engine` is on your PATH (shipped in the plugin's `bin/`); it runs one headless `codex exec` turn with safety pinned (`read-only` or repo-scoped `workspace-write`, `--ignore-user-config`, `--ephemeral`) and prints only Codex's final message.

   - If the call may run long, use the Bash tool's `run_in_background` option rather than blocking (the post-run status/diff then happens after the completion notification).
   - Exit codes: **0** ok · **1** Codex failure (surface the stderr/log excerpt to the user) · **2** usage error (your invocation is wrong — fix it) · **3** not signed in → tell the user to run `codex login` and stop.

   Then emit Codex's output verbatim — no review pass of your own. Only if the status shows new changes vs the step-1 snapshot, add a summary (`git -C <repo> diff --stat`).

   **Persistent start:**

   ```
   plx-codex-thread start --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort>; rc=$?; echo ---; git -C <repo> status --short; rm -rf <tmp>; (exit $rc)
   ```

   **Persistent resume:**

   ```
   plx-codex-thread resume --thread <thread-id> --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort>; rc=$?; echo ---; git -C <repo> status --short; rm -rf <tmp>; (exit $rc)
   ```

   `plx-codex-thread` is packaged with this plugin. It runs the pinned app client through
   `uv`, keeps its environment outside the installed plugin cache, maps `ro` to inspect
   and `rw` to edit, and emits one JSON result. Its first use may need network access to
   prepare the locked environment; request narrowly scoped host approval if the Bash
   sandbox blocks dependency or keychain access. Never enable full access.

   Read `final_response` from the JSON and emit it verbatim. Also return `thread_id`, the
   absolute repo, and `Resume with: /plx:codex resume <thread_id> — <next request>`.
   Re-derive `ro` or `rw` from every resumed request; prior thread access never grants
   write access. On any persistent-path failure, surface the error and stop — never
   silently retry through the ephemeral path, because a failed turn may already have
   changed files.

Request:

$ARGUMENTS
