---
name: claude
description: Explicit single-engine Claude passthrough for Codex. Use for a Claude second opinion, plan, investigation, or implementation without the multi-model Parallax pipeline.
argument-hint: "<question, coding task, or plan request>"
---

# $plx:claude — single-engine passthrough (Claude)

Run the user's request through **Claude only** — no Parallax review pipeline, no other engines. You (the Codex orchestrator) drive the engine wrapper yourself and return its output. Do not re-do or review the work.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing `/skills/claude/SKILL.md`; invoke the packaged wrapper at `<plugin-root>/bin/plx-engine`.

## Resolve launch settings

Resolve the model and effort from the user's request before writing the brief:

- Defaults: `model=opus`, `effort=medium`. Use `high` or `xhigh` instead only for
  concrete cross-file or high-risk work.
- An explicit user model or effort always replaces that setting's default. Natural
  wording is enough: `ask fable medium for <task>`, `use opus at max`, and
  `model=fable effort=low` all set real launch flags.
- Treat `reasoning`, `reasoning level`, and `effort` as names for the same launch
  setting.
- Do not infer an override from model names discussed only as task content. Do not
  normalize, forbid, or silently replace an explicit value. If Claude rejects it,
  surface that error.

Always pass both resolved values as `--model <model> --effort <effort>`.

## Execute

Three tool calls — no subagent.

1. **One shell call** to set up: `git rev-parse --show-toplevel && git status --short && mktemp -d "${TMPDIR:-/tmp}/plx-claude.XXXXXX"`. The first line is `<repo>` (the wrapper needs an absolute `--repo`, and that path is the write boundary); the status snapshot is so pre-existing edits are not later attributed to Claude; the last line is `<tmp>`.
2. **One file edit** to write `<tmp>/prompt.md` as a self-contained brief — Claude runs headless and fresh, seeing only this file plus the repo it reads itself, never your conversation. Lead with the user's request verbatim. Add a short `## Context` heading only when the ask depends on prior conversation decisions. Carry facts and constraints, not your analysis; the passthrough's point is Claude's take.
   Choose `<mode>` from the request: questions, audits, investigations, reviews, and plans use `ro`; only an explicit implementation or edit request uses `rw`. When context says "don't code yet" or equivalent, use `ro`.
3. **One shell call with narrowly scoped host approval** to run, check, and clean up in
   a single `;`-chained command (so status/cleanup run even on engine failure). Codex's
   default host sandbox can hide Claude's OAuth/keychain; Claude safe mode remains the
   engine confinement boundary:

   ```
   <plugin-root>/bin/plx-engine --engine claude --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort> --stdout; rc=$?; outcome=fail; [[ "$rc" -eq 0 ]] && outcome=pass; <plugin-root>/bin/plx-eval finish --skill claude --host codex --repo <repo> --run-dir <tmp> --task-file <tmp>/prompt.md --outcome "$outcome" --verification not-run || echo "plx-eval finish failed (non-fatal)" >&2; echo ---; git -C <repo> status --short; <plugin-root>/bin/plx-clean-temp <tmp>; (exit $rc)
   ```

   The wrapper runs one headless `claude -p` turn with safe mode, no session persistence,
   explicit repository-guidance discovery, and read-only tools or repo-confined sandboxed
   Bash. It prints only Claude's final message.

   - If the call may run long, use a retained execution session and poll it; run status
     and cleanup after completion.
   - Exit codes: **0** ok · **1** Claude failure · **2** wrapper usage error · **3**
     credentials unavailable. After a host-approved call, ask the user to authenticate
     the Claude CLI and stop.

   Emit Claude's output verbatim with no review pass of your own. If status shows new changes, append `git -C <repo> diff --stat`.

Request:

$ARGUMENTS
