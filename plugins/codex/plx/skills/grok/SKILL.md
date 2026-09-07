---
name: grok
description: Single-engine Grok passthrough with overridable model and effort defaults except Grok 4.6 always uses medium, read-only for questions/plans and write-capable only for explicit implementation requests. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
---

# $plx:grok

Run the request through Grok only. Return its answer without redoing or
reviewing the work. Do not launch other engines or subagents.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/grok/SKILL.md`. Use its packaged helpers in `<plugin-root>/bin/`.

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

Write `<tmp>/prompt.md` with the user's request verbatim. Add `## Context` only for
necessary prior decisions, constraints, or paths from the conversation. Keep your own
analysis and proposed solution out of the brief; the engine can inspect the repository.

Use `ro` for questions, audits, investigations, reviews, plans, and "don't code yet"
requests. Use `rw` only for explicit implementation or editing. Run:

```
<plugin-root>/bin/plx-engine --engine grok --mode <ro|rw> --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> --effort <effort> --stdout
```

Use a retained background session for a long call. Save the wrapper exit code and final
output before status checks or cleanup. Trust exit codes: 0 success, 1 engine failure,
2 invocation error, 3 unavailable credentials. Surface the diagnostic on failure;
credentials require user authentication.

If the host sandbox blocks network or keychain access, request narrowly scoped host approval
for the wrapper call. Keep the engine sandbox active. If credentials remain unavailable,
ask the user to authenticate the CLI and stop.

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
<plugin-root>/bin/plx-eval finish --skill grok --host codex --repo <repo> --run-dir <tmp> \
  --task-file <tmp>/prompt.md --outcome <pass|fail> --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

On success, emit the engine's final output verbatim. If it changed files, append diff
statistics attributable to this run; do not attribute pre-existing edits to the engine.

Request:

$ARGUMENTS
