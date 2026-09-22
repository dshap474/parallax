---
name: dev
description: Run Plan, then Build, then Review sequentially for an end-to-end coding task.
argument-hint: "<coding task>"
---

# $plx:dev

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/dev/SKILL.md`. Use the packaged helpers in `<plugin-root>/bin/`.

Run these skills sequentially, using their own instructions and model defaults:

1. Load `<plugin-root>/bin/plx-skill plan` and follow `$plx:plan` for the user's request.
2. After Plan completes, load `<plugin-root>/bin/plx-skill build` and follow `$plx:build`
   with the reviewed plan.
3. After Build completes, load `<plugin-root>/bin/plx-skill review` and follow `$plx:review`
   on the task-owned changes, including commits made during Build.

Wait for each stage before starting the next. Review runs its own lanes in parallel.
Invoking Dev authorizes this sequence without another routine approval between stages.
Pause for unresolved material user decisions; stop on a failed or incomplete stage.
Each stage owns its model selection, engine calls, verification, and trace recording.
Do not duplicate those instructions or launch additional lanes from Dev.

Resolve `<repo>` with `git rev-parse --show-toplevel`. Before Plan, create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-dev.XXXXXX"`, save the original request as
`<tmp>/task.md`, and write `Plan -> Build -> Review (sequential)` to `<tmp>/shape.txt`.
Save the initial commit, status, and diffs there so Review can distinguish task-owned
changes from pre-existing work. Give each stage its own temporary run directory.
Carry forward the original request, confirmed decisions, plan, baseline, and stage results.

Summarize the final result, verification, and any unresolved findings. Follow repository
commit rules; Dev grants no additional publication authority.

Before every handled return, record the outcome and clean up:

```
<plugin-root>/bin/plx-eval finish --skill dev --host codex --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

Recorder failure is non-fatal. Keep runtime files outside the repository.

Request:

$ARGUMENTS
