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

Before Plan, note the baseline commit and any pre-existing changes so Build and Review
can separate task-owned work. Wait for each stage before starting the next, and carry
forward the original request, confirmed decisions, plan, baseline, and stage results.
Invoking Dev authorizes the whole sequence; pause only for unresolved material user
decisions, and stop on a failed or incomplete stage. Do not launch lanes from Dev.

Summarize the final result, verification, and any unresolved findings. Follow repository
commit rules; never publish.

Request:

$ARGUMENTS
