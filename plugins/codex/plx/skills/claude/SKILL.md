---
name: claude
description: Explicit single-engine Claude passthrough for Codex. Use for a Claude second opinion, plan, investigation, or implementation without the multi-model Parallax pipeline.
argument-hint: "<question, coding task, or plan request>"
---

# $plx:claude

Run the request through Claude only. Return its answer without redoing or
reviewing the work. Do not launch other engines or subagents.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/claude/SKILL.md`. Use its packaged helpers in `<plugin-root>/bin/`.

## Launch settings

- Defaults: `model=claude-opus-5-5`, `effort=medium`. Use `high` or `xhigh` only when
  concrete complexity or risk warrants it.
- An explicit user model or effort replaces that setting's default, in natural wording
  (`ask claude-opus-5-5 at max for <task>`). Ignore model names that are only task content.
  Do not normalize or silently replace an explicit value; if Claude rejects it, surface
  the error.

Always pass both values as `--model <model> --effort <effort>`.

## Execute

Note `git status` first so you can attribute changes afterwards. In a fresh temp
directory `<tmp>`, write `<tmp>/prompt.md` with the task, preserving the user's
substantive wording and constraints. Drop routing wording such as "use a Claude agent
to ..."; in `## Context`, tell Claude it is the requested agent and should do the task
directly. Add only necessary prior decisions, constraints, or paths. Keep your own
analysis and proposed solution out of the brief.

Claude gets full host filesystem and network access, including SSH configuration and
keys. The user's request still determines whether it may edit files or change a remote
system. Run it in the background for long calls:

```
<plugin-root>/bin/plx-engine --engine claude --mode rw --claude-passthrough-full-access \
  --repo <repo> --prompt-file <tmp>/prompt.md \
  --model <model> --effort <effort> --stdout
```

If the parent host blocks network or keychain access, request host approval for the
wrapper call.

On failure, surface the diagnostic; exit 3 means the user must authenticate the CLI.

## Finish

On success, emit the engine's final output verbatim. If it changed files, append diff
statistics for this run only, not pre-existing edits. Delete `<tmp>`.

Request:

$ARGUMENTS
