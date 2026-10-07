---
name: grok
description: Send a task directly to Grok. Questions and plans are read-only; explicit implementation requests allow edits.
argument-hint: "<question, coding task, or plan request>"
---

# $plx:grok

Run the request through Grok only. Return its answer without redoing or
reviewing the work. Do not launch other engines or subagents.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/grok/SKILL.md`. Use its packaged helpers in `<plugin-root>/bin/`.

## Launch settings

- Defaults: `model=grok-4.6`, `effort=medium`.
- An explicit user model always replaces the default. An explicit effort replaces the
  default for models other than `grok-4.6`; Grok 4.6 always resolves to `medium`.
  Natural wording is enough (`ask grok-composer-2.5-fast low for <task>`). Ignore model
  names that are only task content. Apart from
  pinning Grok 4.6 to medium, do not normalize or silently replace an explicit value;
  if Grok rejects it, surface the error.

Always pass both values as `--model <model> --effort <effort>`.

## Execute

Note `git status` first so you can attribute changes afterwards. In a fresh temp
directory `<tmp>`, write `<tmp>/prompt.md` with the task, preserving the user's
substantive wording and constraints. Drop routing wording such as "use a Grok agent
to ..."; in `## Context`, tell Grok it is the requested agent and should do the task
directly. Add only necessary prior decisions, constraints, or paths. Keep your own
analysis and proposed solution out of the brief.

Use `ro` for questions, audits, investigations, reviews, plans, and "don't code yet"
requests. Use `rw` only for explicit implementation or editing. Run it in the
background for long calls:

```
<plugin-root>/bin/plx-engine --engine grok --mode <ro|rw> --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> --effort <effort> --stdout
```

If the host sandbox blocks network or keychain access, request narrowly scoped host approval
for the wrapper call. Keep the engine sandbox active.

Judge success by the exit code; `AuthorizationRequired` on stderr can be non-fatal.
On failure, stop. Do not perform the task in the host session, switch engines,
or synthesize a substitute answer. Return `[PLX:GROK FAILED]` with the diagnostic and
any partial changes; for exit 3, direct the user to `grok login`.

## Finish

On success, emit the engine's final output verbatim. If it changed files, append diff
statistics for this run only, not pre-existing edits. Delete `<tmp>`.

Request:

$ARGUMENTS
