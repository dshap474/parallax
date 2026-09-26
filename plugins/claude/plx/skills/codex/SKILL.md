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

## Resolve launch settings

Resolve the model and effort from the user's request before writing the brief:

- Defaults: `model=gpt-6-sol`, `effort=medium`. Use `high` or `xhigh` instead
  only when concrete complexity or risk warrants it.
- An explicit user model or effort replaces that setting's default unless the model
  is retired in Parallax. Natural wording is enough: `ask gpt-6-luna low for <task>`,
  `use gpt-6-sol at xhigh`,
  and `model=gpt-6-sol effort=medium` all set real launch flags.
- Treat `reasoning`, `reasoning level`, and `effort` as names for the same launch
  setting.
- Do not infer an override from model names discussed only as task content. Retired
  Opus 5 and GPT-5.6 Sol/Luna IDs and aliases are rejected by the launcher. Do not
  normalize or silently replace an explicit value. If Codex rejects it, surface
  that error.

Always pass both resolved values as `--model <model> --effort <effort>`, including
on the persistent path.

## Choose the thread mode

Default to the existing **ephemeral** `plx-engine` path. Use a persistent thread only
when the user wants future continuation or repeated turns would materially benefit from
retaining repository context. Complexity alone does not require persistence.

For persistent execution, read [the persistence procedure](references/persistence.md)
before starting or resuming a thread.

## Execute

Resolve `<repo>` with `git rev-parse --show-toplevel`. Snapshot Git status and relevant
diffs to distinguish existing work. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-codex.XXXXXX"`.

Write `<tmp>/prompt.md` with the task for Codex, preserving the user's substantive
wording and constraints. Treat this skill invocation and host-directed wording such as
"use a Codex agent to ..." as routing already fulfilled; omit that routing wording
from the brief. In `## Context`, tell Codex it is the requested agent and should do the
task directly. Add only necessary prior decisions, constraints, or paths from the
conversation. Keep your own analysis and proposed solution out of the brief; Codex
can inspect the repository.

Give Codex full host filesystem and network access for every request, including
SSH configuration and keys. The user's request still determines whether Codex
may edit files or change a remote system. For ephemeral execution, run:

```
plx-engine --engine codex --mode rw --codex-passthrough-full-access \
  --repo <repo> --prompt-file <tmp>/prompt.md \
  --model <model> --effort <effort> --stdout
```

Use a retained background session for a long call. Save the wrapper exit code and final
output before status checks or cleanup. Trust exit codes: 0 success, 1 engine failure,
2 invocation error, 3 unavailable credentials. Surface the diagnostic on failure;
credentials require user authentication.

## Finish

Even on failure, compare final Git status/diffs with the baseline, record the outcome,
and clean up. Do not let a recorder or cleanup result replace the engine exit status.
Use `pass` on engine success and `fail` otherwise; this passthrough performs no independent
verification.

```
plx-eval finish --skill codex --host claude --repo <repo> --run-dir <tmp> \
  --task-file <tmp>/prompt.md --outcome <pass|fail> --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

On success, emit the engine's final output verbatim. If it changed files, append diff
statistics attributable to this run; do not attribute pre-existing edits to the engine.

Request:

$ARGUMENTS
