---
name: build
description: Implement and verify an accepted spec through one gpt-6.1-sol worker at medium reasoning.
argument-hint: "<accepted spec path, or omit when an accepted spec is already in this conversation>"
---

# $plx:build

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/build/SKILL.md`. Use the packaged helpers in `<plugin-root>/bin/`.

Implement and verify the accepted spec through exactly one fresh worker. Use a supplied
spec or the accepted plan in this conversation; if neither exists, direct the user to
`$plx:plan`. Within a Dev run, Plan's returned plan is enough unless a material user
decision is unresolved.

In a fresh temp directory `<tmp>`, write `<tmp>/writer-brief.md`:

```markdown
## Spec
<accepted spec verbatim>
## Build run context
- Repo: <repo>
- Baseline commit: <HEAD hash>
- Pre-existing changes: <git status --short, or none>
- Verification suite: <relevant repository commands and spec acceptance checks>
```

Launch one worker and wait:

```
<plugin-root>/bin/plx-engine --engine codex --mode rw --repo <repo> \
  --prompt-file <tmp>/writer-brief.md --rubric build-worker \
  --build-writer-full-access --model gpt-6.1-sol --effort medium \
  --out <tmp>/writer.md --log <tmp>/writer.log
```

If the host sandbox blocks the worker's network or keychain access, request
narrowly scoped host approval for the wrapper call; preserve its specified transport.

Read the worker report and the diff since the baseline, including new commits. Check
spec coverage and verification evidence. Report failures, missing checks, or unresolved
decisions as partial or blocked; do not substitute another worker. Build does not
review; Review owns that. Return changed files, commit hashes, checks and results, and
residuals to the user or Dev. Delete `<tmp>` when done.

Request:

$ARGUMENTS
