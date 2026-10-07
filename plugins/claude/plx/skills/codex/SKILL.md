---
name: codex
description: Single-engine Codex passthrough with full host access for a question, plan, investigation, or implementation. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:codex

Run the request through Codex only. Return its answer without redoing or
reviewing the work. Do not launch other engines or subagents.

Use the packaged helpers on PATH.

## Launch settings

- Defaults: `model=gpt-6.1-sol`, `effort=medium`. Use `high` or `xhigh` only when
  concrete complexity or risk warrants it.
- An explicit user model or effort replaces that setting's default, in natural wording
  (`ask gpt-6-luna low for <task>`). Ignore model names that are only task content.
  Do not normalize or silently replace an explicit value; if Codex rejects it, surface
  the error.

Always pass both values as `--model <model> --effort <effort>`, including on the persistent path.

Default to the existing **ephemeral** `plx-engine` path. Use a persistent thread only when
the user wants future continuation or repeated turns would materially benefit from
retained repository context; then follow [the persistence procedure](references/persistence.md).

## Execute

Note `git status` first so you can attribute changes afterwards. In a fresh temp
directory `<tmp>`, write `<tmp>/prompt.md` with the task, preserving the user's
substantive wording and constraints. Drop routing wording such as "use a Codex agent
to ..."; in `## Context`, tell Codex it is the requested agent and should do the task
directly. Add only necessary prior decisions, constraints, or paths. Keep your own
analysis and proposed solution out of the brief.

Codex gets full host filesystem and network access, including SSH configuration and
keys. The user's request still determines whether it may edit files or change a remote
system. Run it in the background for long calls:

```
plx-engine --engine codex --mode rw --codex-passthrough-full-access \
  --repo <repo> --prompt-file <tmp>/prompt.md \
  --model <model> --effort <effort> --stdout
```

On failure, surface the diagnostic; exit 3 means the user must authenticate the CLI.

## Finish

On success, emit the engine's final output verbatim. If it changed files, append diff
statistics for this run only, not pre-existing edits. Delete `<tmp>`.

Request:

$ARGUMENTS
