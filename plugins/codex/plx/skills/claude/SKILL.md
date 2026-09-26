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

## Resolve launch settings

Resolve the model and effort from the user's request before writing the brief:

- Defaults: `model=claude-opus-5-5`, `effort=medium`. Use `high` or `xhigh` instead only for
  concrete cross-file or high-risk work.
- An explicit user model or effort replaces that setting's default unless the model
  is retired in Parallax. Examples: `use claude-opus-5-5 at medium for <task>`,
  `use claude-opus-5-5 at max`,
  and `model=fable effort=low` all set real launch flags.
- Treat `reasoning`, `reasoning level`, and `effort` as names for the same launch
  setting.
- Do not infer an override from model names discussed only as task content. Retired
  Opus 5 and GPT-5.6 Sol/Luna IDs and aliases are rejected by the launcher. Do not
  normalize or silently replace an explicit value. If Claude rejects it, surface
  that error.

Always pass both resolved values as `--model <model> --effort <effort>`.

## Execute

Resolve `<repo>` with `git rev-parse --show-toplevel`. Snapshot Git status and relevant
diffs to distinguish existing work. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-claude.XXXXXX"`.

Write `<tmp>/prompt.md` with the task for Claude, preserving the user's substantive
wording and constraints. Treat this skill invocation and host-directed wording such as
"use a Claude agent to ..." as routing already fulfilled; omit that routing wording
from the brief. In `## Context`, tell Claude it is the requested agent and should do the
task directly. Add only necessary prior decisions, constraints, or paths from the
conversation. Keep your own analysis and proposed solution out of the brief; Claude
can inspect the repository.

Use the full-access Claude passthrough for every request. It gives Claude the
same host filesystem and network access as this Codex session, including SSH
configuration and keys. The user's request still determines whether Claude may
edit files or change a remote system. Run:

```
<plugin-root>/bin/plx-engine --engine claude --mode rw --claude-passthrough-full-access \
  --repo <repo> --prompt-file <tmp>/prompt.md \
  --model <model> --effort <effort> --stdout
```

Use a retained background session for a long call. Save the wrapper exit code and final
output before status checks or cleanup. Trust exit codes: 0 success, 1 engine failure,
2 invocation error, 3 unavailable credentials. Surface the diagnostic on failure;
credentials require user authentication.

If the parent host blocks network or keychain access, request host approval for
the wrapper call. If credentials remain unavailable, ask the user to authenticate
the CLI and stop.

## Finish

Even on failure, compare final Git status/diffs with the baseline, record the outcome,
and clean up. Do not let a recorder or cleanup result replace the engine exit status.
Use `pass` on engine success and `fail` otherwise; this passthrough performs no independent
verification.

```
<plugin-root>/bin/plx-eval finish --skill claude --host codex --repo <repo> --run-dir <tmp> \
  --task-file <tmp>/prompt.md --outcome <pass|fail> --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

On success, emit the engine's final output verbatim. If it changed files, append diff
statistics attributable to this run; do not attribute pre-existing edits to the engine.

Request:

$ARGUMENTS
