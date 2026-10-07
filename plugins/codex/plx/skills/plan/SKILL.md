---
name: plan
description: Author a plan in the host and review it once with claude-fable-5-1. Write no code.
argument-hint: "<task to plan>"
---

# $plx:plan

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/plan/SKILL.md`. Use the packaged helpers in `<plugin-root>/bin/`.

Author the plan yourself, then have one read-only opposite-engine reviewer critique it
once. Do not build, commit, or publish.

Read relevant repository guidance, code, and tests. Ask only questions that materially
change the plan. State scope, the proposed approach, and concrete `Done means:` checks.
Keep the plan in the conversation unless persistence is useful; for a persisted spec,
use `<plugin-root>/bin/plx-skill --ref plan/spec-template`. Never edit `.project/VISION.md`.

In a fresh temp directory `<tmp>`, write `<tmp>/critic-brief.md`:

```markdown
## Draft plan
### Original request
<original request verbatim>
### Confirmed decisions
<user clarifications, or none>
### Candidate plan
<draft plan verbatim>
```

Run the reviewer and wait for its result:

```
<plugin-root>/bin/plx-engine --engine claude --mode ro --repo <repo> \
  --prompt-file <tmp>/critic-brief.md --rubric plan-critic \
  --model claude-fable-5-1 --effort high \
  --out <tmp>/critic.md --log <tmp>/critic.log
```

If the host sandbox blocks the reviewer's network or keychain access, request
narrowly scoped host approval for the wrapper call; keep its sandbox active.

Verify material findings against the repository and revise the plan. If the reviewer
fails, say the plan is unreviewed; do not substitute a model. Present the final plan and
material review dispositions. When called by Dev, return the plan and its status to Dev.
Delete `<tmp>` when done.

Request:

$ARGUMENTS
