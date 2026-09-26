---
name: grok
description: Send a task directly to Grok. Questions and plans are read-only; explicit implementation requests allow edits.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:grok

Run the request through Grok only. Return its answer without redoing or
reviewing the work. Do not launch other engines or subagents.

Use the packaged helpers on PATH.

## Resolve launch settings

Resolve the model and effort from the user's request before writing the brief:

- Defaults: `model=grok-4.6`, `effort=medium`.
- An explicit user model always replaces the default. An explicit effort replaces the
  default for models other than `grok-4.6`; Grok 4.6 always resolves to `medium`.
  Natural wording is enough: `ask grok-composer-2.5-fast low for <task>` and
  `model=grok-4.6 effort=medium` both set real launch flags.
- Treat `reasoning`, `reasoning level`, and `effort` as names for the same launch
  setting.
- Do not infer an override from model names discussed only as task content. Apart from
  pinning Grok 4.6 to medium, do not normalize, forbid, or silently replace an explicit
  value. If Grok rejects it, surface that error.

Always pass both resolved values as `--model <model> --effort <effort>`.

## Execute

Resolve `<repo>` with `git rev-parse --show-toplevel`. Snapshot Git status and relevant
diffs to distinguish existing work. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-grok.XXXXXX"`.

Write `<tmp>/prompt.md` with the task for Grok, preserving the user's substantive
wording and constraints. Treat this skill invocation and host-directed wording such as
"use a Grok agent to ..." as routing already fulfilled; omit that routing wording
from the brief. In `## Context`, tell Grok it is the requested agent and should do the
task directly. Add only necessary prior decisions, constraints, or paths from the
conversation. Keep your own analysis and proposed solution out of the brief; Grok
can inspect the repository.

Use `ro` for questions, audits, investigations, reviews, plans, and "don't code yet"
requests. Use `rw` only for explicit implementation or editing. Run:

```
plx-engine --engine grok --mode <ro|rw> --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> --effort <effort> --stdout
```

Use a retained background session for a long call. Save the wrapper exit code and final
output before status checks or cleanup. Trust exit codes: 0 success, 1 engine failure,
2 invocation error, 3 unavailable credentials. Surface the diagnostic on failure;
credentials require user authentication.

Disable the Bash sandbox for the Grok call (`dangerouslyDisableSandbox: true`);
Grok's kernel read-only or workspace sandbox remains active.

Judge success by the exit code; `AuthorizationRequired` on stderr can be non-fatal.
Any nonzero exit ends this skill. Do not perform the task in the host session, switch
engines, or synthesize a substitute answer. Return `[PLX:GROK FAILED]`, the wrapper
diagnostic and relevant log excerpt, and any possible partial changes. For exit 3,
direct the user to `grok login`.

## Finish

Even on failure, compare final Git status/diffs with the baseline, record the outcome,
and clean up. Do not let a recorder or cleanup result replace the engine exit status.
Use `pass` on engine success and `fail` otherwise; this passthrough performs no independent
verification.

```
plx-eval finish --skill grok --host claude --repo <repo> --run-dir <tmp> \
  --task-file <tmp>/prompt.md --outcome <pass|fail> --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

On success, emit the engine's final output verbatim. If it changed files, append diff
statistics attributable to this run; do not attribute pre-existing edits to the engine.

Request:

$ARGUMENTS
