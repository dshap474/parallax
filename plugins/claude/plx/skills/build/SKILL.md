---
name: build
description: Implement and verify an accepted spec through one claude-opus-5-5 worker at medium reasoning.
argument-hint: "<accepted spec path, or omit when an accepted spec is already in this conversation>"
disable-model-invocation: true
user-invocable: true
---

# /plx:build

Use the packaged helpers on PATH.

Use exactly one fresh worker to implement and verify the accepted spec.
Use a supplied spec or the accepted plan in this conversation. If neither exists,
direct the user to `/plx:plan`. A plan returned by Plan within an authorized Dev
run is sufficient unless a material user decision remains unresolved.

Resolve `<repo>` with `git rev-parse --show-toplevel`. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-build.XXXXXX"`. Save the baseline commit, Git status,
and staged/unstaged diffs there. Preserve pre-existing work.
Write the spec verbatim to `<tmp>/task.md` and the worker model/effort to
`<tmp>/shape.txt`. Run `plx-preflight --repo <repo> --require-claude`.

Write `<tmp>/writer-brief.md` containing:

```markdown
## Spec
<accepted spec verbatim>
## Build run context
- Repo: <repo>
- Baseline commit: <commit hash>
- Baseline snapshots: <paths to saved status and diffs>
- Verification suite: <relevant repository commands and spec acceptance checks>
```

Launch one worker and wait:

```
plx-engine --engine claude --mode rw --repo <repo> \
  --prompt-file <tmp>/writer-brief.md --rubric build-worker \
  --build-writer-full-access --model claude-opus-5-5 --effort medium \
  --out <tmp>/writer.md --log <tmp>/writer.log
```

Full host access is limited to this writer for repository Git metadata. It grants no
additional scope or publication authority. Use packaged wrappers and named rubrics;
no raw engine commands, pasted rubrics, or subagents. Never `uv run` inside a sandbox.
If the host sandbox blocks Claude or Grok network/keychain access, request narrowly scoped host approval for that call; keep each lane's specified transport.

Read the worker report and task-owned diff, including any commits since the baseline.
Check spec coverage and verification evidence. Report failures, missing checks, or
unresolved decisions as partial or blocked. Do not silently substitute another worker.
Build runs no review lanes; Review owns that stage.
Write `<tmp>/report.md` with changed files, commit hashes, checks/results, and residuals;
return that summary to the user or Dev.

Before every handled return, record the outcome and clean up:

```
plx-eval finish --skill build --host claude --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt --report-file <tmp>/report.md \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

Omit `--report-file` if no report exists yet. Recorder failure is non-fatal. Keep runtime files outside the repository.

Request:

$ARGUMENTS
