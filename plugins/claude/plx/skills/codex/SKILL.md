---
name: codex
description: Single-engine passthrough — the orchestrator runs Codex headless with read-only access for questions/plans and write access only for explicit implementation requests. No multi-model review pipeline.
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

Announce persistence and its reason. Resume only a supplied thread ID or one unambiguous
ID previously returned in this conversation. Persistent threads belong only to this
passthrough; do not reuse them for pipeline lanes.

## Execute

Resolve `<repo>` with `git rev-parse --show-toplevel`. Snapshot Git status and relevant
diffs to distinguish existing work. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-codex.XXXXXX"`.

Write `<tmp>/prompt.md` with the user's request verbatim. Add `## Context` only for
necessary prior decisions, constraints, or paths from the conversation. Keep your own
analysis and proposed solution out of the brief; the engine can inspect the repository.

Use `ro` for questions, audits, investigations, reviews, plans, and "don't code yet"
requests. Use `rw` only for explicit implementation or editing. Run:

```
plx-engine --engine codex --mode <ro|rw> --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> --effort <effort> --stdout
```

Use a retained background session for a long call. Save the wrapper exit code and final
output before status checks or cleanup. Trust exit codes: 0 success, 1 engine failure,
2 invocation error, 3 unavailable credentials. Surface the diagnostic on failure;
credentials require user authentication.

For persistent execution, replace the engine command with one of:

```
plx-codex-thread start --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort>
plx-codex-thread resume --thread <thread-id> --mode <ro|rw> --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort>
```

Re-derive access mode on every resume; prior write access grants no new authority.
The packaged client prepares its locked environment outside the plugin cache. If the
host sandbox blocks dependency or keychain access, request narrowly scoped approval;
never enable full access. Read `final_response` from the JSON result. Return it verbatim
with `thread_id`, the absolute repo, and `Resume with: /plx:codex resume <thread_id> —
<next request>`. On persistent failure, report the error and stop; do not retry through
the ephemeral path because the failed turn may have changed files.

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
