---
name: gemini
description: Single-engine Gemini CLI passthrough for questions, reviews, plans, and explicit file edits. Supports model selection; no shell execution or multi-model pipeline.
argument-hint: "<request> [model=<model>]"
---

# $plx:gemini

Run the request through Gemini CLI only. Do not launch another engine or redo its answer.
Resolve `<plugin-root>` from this file by removing `/skills/gemini/SKILL.md`.

## Execute

Resolve `<repo>` with `git rev-parse --show-toplevel` and snapshot its status/diffs.
Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-gemini.XXXXXX"`.
Write `<tmp>/prompt.md` with the task for Gemini, preserving the user's substantive
wording and constraints. Treat this skill invocation and host-directed wording such as
"use a Gemini agent to ..." as routing already fulfilled; omit that routing wording
from the brief. Tell Gemini it is the requested agent and should do the task directly.
Add only necessary prior context and repository guidance, not your proposed solution.

Use `ro` for questions, reviews, and plans; use `rw` only for explicit editing requests.
The default model is `auto`; pass an explicit user model unchanged. Gemini has no
PLX effort setting. Explain an unsupported effort request instead of silently ignoring it.

```text
<plugin-root>/bin/plx-engine --engine gemini --mode <ro|rw> --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> --stdout
```

Use a retained background session for long calls. The wrapper enables the sandbox,
disables extensions/MCP/hooks, and exposes read tools in `ro` or read/edit tools in `rw`.
Shell execution is unavailable, including test commands. Disclose any unrun validation.
This transport currently requires macOS Seatbelt. Never bypass a failed sandbox.
Inherited extra `includeDirectories` are rejected, and existing settings must be plain JSON.
Gemini CLI must already be installed and authenticated; the wrapper does not install,
upgrade, or switch to Antigravity CLI. It may retain native Gemini session history.

Save the engine exit status and output before cleanup. Exit 0 means success, 1 engine
failure, 2 invalid invocation, and 3 missing authentication. On failure return
`[PLX:GEMINI FAILED]` with the diagnostic and any partial changes. For exit 3, direct
the user to authenticate with `gemini` or configure `GEMINI_API_KEY`; preserve
any account-specific project-ID diagnostic. Do not retry with
another engine or substitute a host answer.

## Finish

Compare final status/diffs with the baseline even on failure. Record and clean up without
replacing the engine exit status:

```text
<plugin-root>/bin/plx-eval finish --skill gemini --host codex --repo <repo> --run-dir <tmp> \
  --task-file <tmp>/prompt.md --outcome <pass|fail> --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

On success return Gemini's final output verbatim, then append attributable diff statistics
and any validation limitation. This passthrough performs no independent review.

Request:

$ARGUMENTS
